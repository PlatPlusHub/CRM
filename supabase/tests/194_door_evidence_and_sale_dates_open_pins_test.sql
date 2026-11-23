-- pgTAP: the open table-door findings of the documents/quotations re-sweep and the backdated sale (DOC-11, QUO-11,
-- QUO-12, BOOK-13), pinned as OPEN.
--
-- EC-8 / gate re-sweep: SPEC-335 measured each finding at 676df3e and registered it with its class and boundary.
--   Each OPEN assertion below records the defect as it stands; it is NOT desired behaviour. As Test 130 pins
--   BRANCH-2, each one FAILS when its finding is repaired, so the repair must update this file and the register
--   in the same change. A repair that refuses the door write fails the lives_ok step instead.
--   * DOC-11: a document created at the table door records no document_uploaded, while app.upload_document does.
--   * QUO-11: a quotation created at the table door records no quotation_created, and door transitions to sent and
--     accepted record nothing and leave sent_at and accepted_at null.
--   * QUO-12: the assigned member renumbers and re-leads a quotation, and a manager reassigns its owner, at the
--     table door with no event; no RPC offers these changes.
--   * BOOK-13: a member chooses or rewrites the creation date of their own booking and booking item, and
--     reporting.sales_activity and reporting.my_sales_performance report the chosen date.
create extension if not exists pgtap with schema extensions;

begin;
select plan(11);

insert into auth.users (id, email) values
  ('19400000-0000-0000-0000-0000000000a1','emp@t194.test'),
  ('19400000-0000-0000-0000-0000000000a2','mgr@t194.test');
insert into public.tenants (id, name, slug, status) values
  ('19400000-0000-0000-0000-000000000001','T194 Travel','t194-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '19400000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp
where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('19400000-0000-0000-0000-00000000000a','19400000-0000-0000-0000-000000000001','Cairo','t194-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('19400000-0000-0000-0000-0000000000c1','19400000-0000-0000-0000-000000000001','19400000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('19400000-0000-0000-0000-000000000011','19400000-0000-0000-0000-000000000001','Emp','emp@t194.test',true,'19400000-0000-0000-0000-0000000000a1'),
  ('19400000-0000-0000-0000-000000000021','19400000-0000-0000-0000-000000000001','Mgr','mgr@t194.test',true,'19400000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '19400000-0000-0000-0000-000000000001', u, '19400000-0000-0000-0000-00000000000a', '19400000-0000-0000-0000-0000000000c1', true
from unnest(array['19400000-0000-0000-0000-000000000011'::uuid,'19400000-0000-0000-0000-000000000021']) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '19400000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('19400000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('19400000-0000-0000-0000-000000000021'::uuid,'branch_manager')) v(u, rc)
join public.roles r on r.code = v.rc;
insert into public.customers (id, tenant_id, customer_type_code, full_name, first_registered_branch_id) values
  ('19400000-0000-0000-0000-0000000000d1','19400000-0000-0000-0000-000000000001','person','Buyer','19400000-0000-0000-0000-00000000000a');
insert into public.suppliers (id, tenant_id, name, supplier_type_code) values
  ('19400000-0000-0000-0000-0000000000e1','19400000-0000-0000-0000-000000000001','Nile Air','airline');
insert into public.leads (id, tenant_id, branch_id, department_id, customer_id, lead_source_code, title, lead_status_code) values
  ('19400000-0000-0000-0000-0000000000f1','19400000-0000-0000-0000-000000000001','19400000-0000-0000-0000-00000000000a','19400000-0000-0000-0000-0000000000c1','19400000-0000-0000-0000-0000000000d1','direct_call','Lead A','new'),
  ('19400000-0000-0000-0000-0000000000f2','19400000-0000-0000-0000-000000000001','19400000-0000-0000-0000-00000000000a','19400000-0000-0000-0000-0000000000c1','19400000-0000-0000-0000-0000000000d1','direct_call','Lead B','new');
-- Written as `postgres`: emp's booking and the item emp sold.
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
    owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
  ('19400000-0000-0000-0000-0000000000b1','19400000-0000-0000-0000-000000000001','19400000-0000-0000-0000-00000000000a','19400000-0000-0000-0000-0000000000c1','19400000-0000-0000-0000-0000000000d1','19400000-0000-0000-0000-000000000011','19400000-0000-0000-0000-00000000000a','19400000-0000-0000-0000-0000000000c1','draft','Trip','T194-B1');
insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code,
    currency_code, cost_amount, selling_amount, owner_user_id, owner_branch_id, owner_department_id,
    sales_owner_user_id, sales_owner_branch_id, sales_owner_department_id) values
  ('19400000-0000-0000-0000-0000000000b2','19400000-0000-0000-0000-000000000001','19400000-0000-0000-0000-0000000000b1','hotel','draft','EGP',100,150,'19400000-0000-0000-0000-000000000011','19400000-0000-0000-0000-00000000000a','19400000-0000-0000-0000-0000000000c1','19400000-0000-0000-0000-000000000011','19400000-0000-0000-0000-00000000000a','19400000-0000-0000-0000-0000000000c1');

-- Events recorded on the quotation or document with this number or title, other than the excluded type.
create function pg_temp.t194_q(p_number text, p_not text default '') returns int language sql as $$
  select count(e.id)::int from public.quotations q join public.events e on e.entity_id = q.id
  where q.tenant_id = '19400000-0000-0000-0000-000000000001' and q.quotation_number = p_number
    and e.event_type_code <> p_not
$$;
create function pg_temp.t194_d(p_title text) returns int language sql as $$
  select count(e.id)::int from public.documents d join public.events e on e.entity_id = d.id
  where d.tenant_id = '19400000-0000-0000-0000-000000000001' and d.title = p_title
$$;
grant execute on function pg_temp.t194_q(text, text) to authenticated;
grant execute on function pg_temp.t194_d(text) to authenticated;

-- ================================================================================================
-- emp: the RPC doors (positive controls) and the table doors (OPEN pins)
-- ================================================================================================
select set_config('request.jwt.claims','{"sub":"19400000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;

select app.create_quotation('19400000-0000-0000-0000-0000000000d1','EGP','19400000-0000-0000-0000-0000000000f1',null,'T194-RPC');
select is(pg_temp.t194_q('T194-RPC'), 1,
  'POSITIVE CONTROL: app.create_quotation records exactly one quotation_created');

select lives_ok(
  $$insert into public.quotations (tenant_id, customer_id, owner_user_id, owner_branch_id, owner_department_id,
      quotation_status_code, quotation_number, currency_code, total_amount)
    values ('19400000-0000-0000-0000-000000000001','19400000-0000-0000-0000-0000000000d1',
      '19400000-0000-0000-0000-000000000011','19400000-0000-0000-0000-00000000000a',
      '19400000-0000-0000-0000-0000000000c1','draft','T194-DOOR','EGP',0)$$,
  'the assigned member creates a quotation at the table door');
select is(pg_temp.t194_q('T194-DOOR'), 0,
  'QUO-11 is OPEN: a quotation created at the table door records no event (FAILS when QUO-11 is repaired)');

select lives_ok(
  $$update public.quotations set quotation_number = 'T194-RENUMBERED', lead_id = '19400000-0000-0000-0000-0000000000f2'
     where tenant_id = '19400000-0000-0000-0000-000000000001' and quotation_number = 'T194-RPC'$$,
  'QUO-12 is OPEN: the assigned member renumbers and re-leads a quotation at the table door (FAILS when the door refuses it)');
select is(pg_temp.t194_q('T194-RENUMBERED', 'quotation_created'), 0,
  'QUO-12 is OPEN: the renumbering and re-leading record no event (FAILS when QUO-12 is repaired)');

select app.upload_document('contract','T194 rpc doc','a.pdf','pdf','supplier','19400000-0000-0000-0000-0000000000e1',100,null,false);
select ok(pg_temp.t194_d('T194 rpc doc') > 0,
  'POSITIVE CONTROL: app.upload_document records its events');

insert into public.documents (tenant_id, document_type_code, title, lifecycle_status_code, is_confidential)
  values ('19400000-0000-0000-0000-000000000001','contract','T194 door doc','active',false);
select is(pg_temp.t194_d('T194 door doc'), 0,
  'DOC-11 is OPEN: a document created at the table door records no event (FAILS when DOC-11 is repaired)');

insert into public.bookings (tenant_id, branch_id, department_id, customer_id, owner_user_id, booking_status_code,
    title, booking_reference, created_at)
  values ('19400000-0000-0000-0000-000000000001','19400000-0000-0000-0000-00000000000a',
    '19400000-0000-0000-0000-0000000000c1','19400000-0000-0000-0000-0000000000d1',
    '19400000-0000-0000-0000-000000000011','draft','Backdated','T194-B2','2001-01-01');
select is((select string_agg(activity_date::text || ':' || bookings_created, ',' order by activity_date)
             from public.sales_activity where owner_user_id = '19400000-0000-0000-0000-000000000011'),
  '2001-01-01:1,' || current_date::text || ':1',
  'BOOK-13 is OPEN: a booking created at the table door keeps the creation date its member chose, and the sales activity report counts it on that date (FAILS when BOOK-13 is repaired)');

update public.booking_items set created_at = '2001-01-01' where id = '19400000-0000-0000-0000-0000000000b2';
select is((select sold_at::date from public.my_sales_performance
            where booking_item_id = '19400000-0000-0000-0000-0000000000b2'), '2001-01-01'::date,
  'BOOK-13 is OPEN: the sales owner rewrites a sold item''s creation date and the performance report shows it as sold then (FAILS when BOOK-13 is repaired)');

-- ================================================================================================
-- mgr: door transitions and reassignment (OPEN pins)
-- ================================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"19400000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
set local role authenticated;

select app.add_quotation_item((select id from public.quotations where quotation_number = 'T194-RENUMBERED'),'hotel',100,1,'x');
update public.quotations set quotation_status_code = 'sent' where quotation_number = 'T194-RENUMBERED';
update public.quotations set quotation_status_code = 'accepted' where quotation_number = 'T194-RENUMBERED';
select is((select quotation_status_code || '/' || coalesce(sent_at::text, 'null') || '/' || coalesce(accepted_at::text, 'null')
                  || '/' || pg_temp.t194_q('T194-RENUMBERED', 'quotation_created')
             from public.quotations where quotation_number = 'T194-RENUMBERED'),
  'accepted/null/null/0',
  'QUO-11 is OPEN: door transitions to sent and accepted record no event and leave sent_at and accepted_at null (FAILS when QUO-11 is repaired)');

update public.quotations set owner_user_id = '19400000-0000-0000-0000-000000000021' where quotation_number = 'T194-RENUMBERED';
select is((select owner_user_id::text || '/' || pg_temp.t194_q('T194-RENUMBERED', 'quotation_created')
             from public.quotations where quotation_number = 'T194-RENUMBERED'),
  '19400000-0000-0000-0000-000000000021/0',
  'QUO-12 is OPEN: a manager reassigns the quotation''s owner at the table door with no event (FAILS when QUO-12 is repaired)');

reset role;
select * from finish();
rollback;
