-- pgTAP: Batch 6 slice 50 (DOC-9, DOC-10) --
-- a document is linked only by someone who can already read it, and a moved link is recorded
-- (`20261112150000`).
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE=N/A INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS OBSERVABILITY
--   STATE=N/A -- a link has no lifecycle; its only change is a move, which is checked and recorded here.
--   CONCURRENCY=N/A -- the check reads committed visibility of one document; no counter or claim.
--   REPLAY=N/A -- no token, nonce or idempotency key on this surface.
create extension if not exists pgtap with schema extensions;

begin;
select plan(16);

insert into auth.users (id, email) values
  ('16500000-0000-0000-0000-0000000000a1','giza@c165.test'),
  ('16500000-0000-0000-0000-0000000000a2','suez@c165.test'),
  ('16500000-0000-0000-0000-0000000000a3','owner@c165.test'),
  ('16500000-0000-0000-0000-0000000000a9','other@c165.test');
insert into public.tenants (id, name, slug, status) values
  ('16500000-0000-0000-0000-000000000001','Link Travel','link-travel-165','active'),
  ('16500000-0000-0000-0000-000000000002','Other Travel','other-travel-165','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.subscription_plans sp cross join (values ('16500000-0000-0000-0000-000000000001'::uuid), ('16500000-0000-0000-0000-000000000002'::uuid)) t(id) where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('16500000-0000-0000-0000-00000000000a','16500000-0000-0000-0000-000000000001','Giza','giza-165'),
  ('16500000-0000-0000-0000-00000000000b','16500000-0000-0000-0000-000000000001','Suez','suez-165');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('16500000-0000-0000-0000-0000000000c1','16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-00000000000a','sales','Giza Sales'),
  ('16500000-0000-0000-0000-0000000000c2','16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-00000000000b','sales','Suez Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('16500000-0000-0000-0000-000000000011','16500000-0000-0000-0000-000000000001','Giza','giza@c165.test',true,'16500000-0000-0000-0000-0000000000a1'),
  ('16500000-0000-0000-0000-000000000012','16500000-0000-0000-0000-000000000001','Suez','suez@c165.test',true,'16500000-0000-0000-0000-0000000000a2'),
  ('16500000-0000-0000-0000-000000000013','16500000-0000-0000-0000-000000000001','Owner','owner@c165.test',true,'16500000-0000-0000-0000-0000000000a3'),
  ('16500000-0000-0000-0000-000000000019','16500000-0000-0000-0000-000000000002','Other','other@c165.test',true,'16500000-0000-0000-0000-0000000000a9');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-000000000011','16500000-0000-0000-0000-00000000000a','16500000-0000-0000-0000-0000000000c1',true),
  ('16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-000000000012','16500000-0000-0000-0000-00000000000b','16500000-0000-0000-0000-0000000000c2',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.tid, v.uid, r.id, 'tenant'
from (values ('16500000-0000-0000-0000-000000000001'::uuid,'16500000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-000000000012','employee'),
             ('16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-000000000013','owner'),
             ('16500000-0000-0000-0000-000000000002','16500000-0000-0000-0000-000000000019','owner')) v(tid, uid, role_code)
join public.roles r on r.code = v.role_code;
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('16500000-0000-0000-0000-0000000000d1','16500000-0000-0000-0000-000000000001','person','Link Customer');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                             owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
  ('16500000-0000-0000-0000-0000000000f1','16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-00000000000a','16500000-0000-0000-0000-0000000000c1','16500000-0000-0000-0000-0000000000d1','16500000-0000-0000-0000-000000000011','16500000-0000-0000-0000-00000000000a','16500000-0000-0000-0000-0000000000c1','draft','Giza booking','BK-165-1'),
  ('16500000-0000-0000-0000-0000000000f2','16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-00000000000a','16500000-0000-0000-0000-0000000000c1','16500000-0000-0000-0000-0000000000d1','16500000-0000-0000-0000-000000000011','16500000-0000-0000-0000-00000000000a','16500000-0000-0000-0000-0000000000c1','draft','Giza booking 2','BK-165-2'),
  ('16500000-0000-0000-0000-0000000000f3','16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-00000000000b','16500000-0000-0000-0000-0000000000c2','16500000-0000-0000-0000-0000000000d1','16500000-0000-0000-0000-000000000012','16500000-0000-0000-0000-00000000000b','16500000-0000-0000-0000-0000000000c2','draft','Suez booking','BK-165-3');
-- Dg: Giza's ticket on Giza's booking. Ds and Di: Suez's passport scan and invoice on Suez's booking.
insert into public.documents (id, tenant_id, document_type_code, title, lifecycle_status_code, is_confidential, created_by) values
  ('16500000-0000-0000-0000-0000000000e1','16500000-0000-0000-0000-000000000001','ticket','Dg','active',false,'16500000-0000-0000-0000-000000000011'),
  ('16500000-0000-0000-0000-0000000000e2','16500000-0000-0000-0000-000000000001','passport','Ds','active',false,'16500000-0000-0000-0000-000000000012'),
  ('16500000-0000-0000-0000-0000000000e3','16500000-0000-0000-0000-000000000001','invoice','Di','active',false,'16500000-0000-0000-0000-000000000012');
insert into public.document_links (id, tenant_id, document_id, booking_id) values
  ('16500000-0000-0000-0000-0000000000b1','16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-0000000000e1','16500000-0000-0000-0000-0000000000f1'),
  ('16500000-0000-0000-0000-0000000000b2','16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-0000000000e2','16500000-0000-0000-0000-0000000000f3'),
  ('16500000-0000-0000-0000-0000000000b3','16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-0000000000e3','16500000-0000-0000-0000-0000000000f3');

select is(
  (select count(*)::int from pg_trigger
   where tgrelid = 'public.document_links'::regclass and not tgisinternal
     and tgname in ('document_links_guard_document_readable', 'document_links_emit_move')),
  2, 'both triggers are installed on document_links');

select is(
  (select prosecdef from pg_proc where oid = 'app.guard_document_link_readable'::regproc),
  false, 'the guard is SECURITY INVOKER: the check is the caller''s own read of the document');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"16500000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);

select is((select count(*)::int from public.documents where title in ('Ds','Di')), 0,
  'the Giza employee reads neither Suez document -- the anchor for what follows');

-- DOC-9: a link may not carry a document its writer cannot read.
select throws_ok(
  $$insert into public.document_links (tenant_id, document_id, booking_id) values
    ('16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-0000000000e2','16500000-0000-0000-0000-0000000000f1')$$,
  '42501', 'a document can be linked only by someone who can already read it',
  'DOC-9: the Giza employee cannot link the Suez passport scan onto their own booking');

select throws_ok(
  $$insert into public.document_links (tenant_id, document_id, booking_id) values
    ('16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-0000000000e3','16500000-0000-0000-0000-0000000000f1')$$,
  '42501', 'a document can be linked only by someone who can already read it',
  'DOC-9: ...nor the Suez invoice, which would make them "responsible" for it (SPEC-154-B)');

select throws_ok(
  $$update public.document_links set document_id = '16500000-0000-0000-0000-0000000000e2'
    where id = '16500000-0000-0000-0000-0000000000b1'$$,
  '42501', 'a document can be linked only by someone who can already read it',
  'DOC-9: ...nor re-point their own link at the Suez passport scan');

select is((select count(*)::int from public.documents where title in ('Ds','Di')), 0,
  'and still reads neither Suez document');

-- The legitimate door and the legitimate direct link still work.
select lives_ok(
  $$select app.upload_document('other','Giza upload','g.pdf','pdf','booking','16500000-0000-0000-0000-0000000000f1')$$,
  'app.upload_document still links the document it has just created');

select lives_ok(
  $$insert into public.document_links (tenant_id, document_id, booking_id) values
    ('16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-0000000000e1','16500000-0000-0000-0000-0000000000f2')$$,
  'a document the writer reads may be linked onto another record the writer reads');

select is(
  (select count(*)::int from public.document_links l join public.users u on u.id = l.created_by
   where l.document_id = '16500000-0000-0000-0000-0000000000e1' and l.booking_id = '16500000-0000-0000-0000-0000000000f2'
     and u.full_name = 'Giza'),
  1, 'a new link is attributed by its own row: created_by is the writer');

-- DOC-10: a moved link is recorded, with the previous and the current target.
select lives_ok(
  $$update public.document_links set booking_id = '16500000-0000-0000-0000-0000000000f2'
    where id = '16500000-0000-0000-0000-0000000000b1'$$,
  'the Giza employee may move their own ticket link between two Giza bookings');

reset role;

select is(
  (select count(*)::int from public.events e join public.users u on u.id = e.actor_user_id
   where e.tenant_id = '16500000-0000-0000-0000-000000000001' and e.event_type_code = 'document_linked'
     and e.entity_id = '16500000-0000-0000-0000-0000000000e1' and u.full_name = 'Giza'
     and e.payload -> 'previous' ->> 'booking_id' = '16500000-0000-0000-0000-0000000000f1'
     and e.payload -> 'current' ->> 'booking_id' = '16500000-0000-0000-0000-0000000000f2'
     and e.payload ->> 'link_id' = '16500000-0000-0000-0000-0000000000b1'),
  1, 'DOC-10: the move is recorded once, as document_linked by the mover, with both targets');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"16500000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
update public.document_links set booking_id = '16500000-0000-0000-0000-0000000000f2'
 where id = '16500000-0000-0000-0000-0000000000b1';
reset role;

select is(
  (select count(*)::int from public.events
   where tenant_id = '16500000-0000-0000-0000-000000000001' and event_type_code = 'document_linked'
     and payload ? 'previous'),
  1, 'an update that moves nothing records nothing');

-- TENANT: another tenant's owner sees none of this tenant's documents, so links none of them.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"16500000-0000-0000-0000-0000000000a9","aal":"aal2"}', true);
select throws_ok(
  $$insert into public.document_links (tenant_id, document_id, booking_id) values
    ('16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-0000000000e2','16500000-0000-0000-0000-0000000000f3')$$,
  '42501', null,
  'TENANT: another tenant''s owner cannot link this tenant''s document');

-- The owner reads every document of the tenant (tenant-wide read), so may link any of them.
select set_config('request.jwt.claims', '{"sub":"16500000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
select lives_ok(
  $$insert into public.document_links (tenant_id, document_id, booking_id) values
    ('16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-0000000000e2','16500000-0000-0000-0000-0000000000f1')$$,
  'the owner, who reads every document of the tenant, may link the Suez passport scan anywhere');
reset role;

-- The platform path (no session) is not checked, as in every sibling guard.
select lives_ok(
  $$insert into public.document_links (tenant_id, document_id, booking_id) values
    ('16500000-0000-0000-0000-000000000001','16500000-0000-0000-0000-0000000000e3','16500000-0000-0000-0000-0000000000f2')$$,
  'a session-less platform write is not checked');

select * from finish();
rollback;
