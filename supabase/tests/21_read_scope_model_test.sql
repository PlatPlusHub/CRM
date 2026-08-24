-- pgTAP: the read-scope model (SPEC-137 / AUDIT-3), proven behaviourally.
--
-- THIS TEST IS DIFFERENT FROM EVERY OTHER TEST IN THE SUITE, and the difference is the point.
-- Every other file runs as `postgres`, which owns the tables and therefore BYPASSES row-level
-- security entirely. Those tests prove the permission chain (`app.authorize`) and the constraints;
-- not one of them has ever proven that an RLS policy actually filters a row -- including the tenant
-- isolation the whole system rests on. This file does `set local role authenticated` first, so the
-- policies are genuinely the only thing standing between the caller and the data.
--
-- The fixture is one company with two branches, because a single-branch fixture cannot fail the
-- assertions that matter:
--
--   Cairo (branch A)                        Alexandria (branch B)
--     +- Sales      : alice, bob, tina        +- Sales : dave
--     +- Operations : carol
--   mgr  governs Cairo (branch_manager, branch-scoped role assignment)
--   boss owns the tenant (owner)             finn is finance_manager with NO branch at all
--
-- Every rule is asserted in BOTH directions. "bob can see alice's lead" is only meaningful next to
-- "carol cannot", and neither means anything unless "dave cannot" also holds -- otherwise the model
-- would be passing because it lets everyone through.
create extension if not exists pgtap with schema extensions;

begin;
select plan(24);

-- ---------------------------------------------------------------------------------------------
-- Fixture, built as postgres before any role switch.
-- ---------------------------------------------------------------------------------------------
insert into auth.users (id, email) values
  ('21000000-0000-0000-0000-0000000000a1','alice@example.com'),
  ('21000000-0000-0000-0000-0000000000a2','bob@example.com'),
  ('21000000-0000-0000-0000-0000000000a3','carol@example.com'),
  ('21000000-0000-0000-0000-0000000000a4','dave@example.com'),
  ('21000000-0000-0000-0000-0000000000a5','mgr@example.com'),
  ('21000000-0000-0000-0000-0000000000a6','boss@example.com'),
  ('21000000-0000-0000-0000-0000000000a7','tina@example.com'),
  ('21000000-0000-0000-0000-0000000000a8','finn@example.com');

insert into public.tenants (id, name, slug, status) values
  ('21000000-0000-0000-0000-000000000001','Scope Travel','scope-travel','active');

insert into public.branches (id, tenant_id, name, slug) values
  ('21000000-0000-0000-0000-00000000000a','21000000-0000-0000-0000-000000000001','Cairo','cairo'),
  ('21000000-0000-0000-0000-00000000000b','21000000-0000-0000-0000-000000000001','Alexandria','alexandria');

insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('21000000-0000-0000-0000-0000000000c1','21000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-00000000000a','sales','Cairo Sales'),
  ('21000000-0000-0000-0000-0000000000c2','21000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-00000000000a','operations','Cairo Operations'),
  ('21000000-0000-0000-0000-0000000000c3','21000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-00000000000b','sales','Alexandria Sales');

insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('21000000-0000-0000-0000-000000000011','21000000-0000-0000-0000-000000000001','Alice','alice@example.com',true,'21000000-0000-0000-0000-0000000000a1'),
  ('21000000-0000-0000-0000-000000000012','21000000-0000-0000-0000-000000000001','Bob','bob@example.com',true,'21000000-0000-0000-0000-0000000000a2'),
  ('21000000-0000-0000-0000-000000000013','21000000-0000-0000-0000-000000000001','Carol','carol@example.com',true,'21000000-0000-0000-0000-0000000000a3'),
  ('21000000-0000-0000-0000-000000000014','21000000-0000-0000-0000-000000000001','Dave','dave@example.com',true,'21000000-0000-0000-0000-0000000000a4'),
  ('21000000-0000-0000-0000-000000000015','21000000-0000-0000-0000-000000000001','Manager','mgr@example.com',true,'21000000-0000-0000-0000-0000000000a5'),
  ('21000000-0000-0000-0000-000000000016','21000000-0000-0000-0000-000000000001','Boss','boss@example.com',true,'21000000-0000-0000-0000-0000000000a6'),
  ('21000000-0000-0000-0000-000000000017','21000000-0000-0000-0000-000000000001','Tina','tina@example.com',true,'21000000-0000-0000-0000-0000000000a7'),
  ('21000000-0000-0000-0000-000000000018','21000000-0000-0000-0000-000000000001','Finn','finn@example.com',true,'21000000-0000-0000-0000-0000000000a8');

-- Where each person WORKS. Finn (finance) deliberately has no placement: finance authority must not
-- depend on sitting in a branch, and that is only demonstrable if he sits in none.
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('21000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000011','21000000-0000-0000-0000-00000000000a','21000000-0000-0000-0000-0000000000c1',true),
  ('21000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000012','21000000-0000-0000-0000-00000000000a','21000000-0000-0000-0000-0000000000c1',true),
  ('21000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000013','21000000-0000-0000-0000-00000000000a','21000000-0000-0000-0000-0000000000c2',true),
  ('21000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000014','21000000-0000-0000-0000-00000000000b','21000000-0000-0000-0000-0000000000c3',true),
  ('21000000-0000-0000-0000-000000000001','21000000-0000-0000-0000-000000000017','21000000-0000-0000-0000-00000000000a','21000000-0000-0000-0000-0000000000c1',true);

-- What each person GOVERNS. The manager's authority is a branch-scoped role assignment, which is a
-- different fact from a branch placement -- the model unions both, and this proves the RBAC half.
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type, branch_id)
select '21000000-0000-0000-0000-000000000001', v.uid, r.id, v.scope, v.branch
from (values
  ('21000000-0000-0000-0000-000000000011'::uuid,'employee','tenant',null::uuid),
  ('21000000-0000-0000-0000-000000000012'::uuid,'employee','tenant',null),
  ('21000000-0000-0000-0000-000000000013'::uuid,'employee','tenant',null),
  ('21000000-0000-0000-0000-000000000014'::uuid,'employee','tenant',null),
  ('21000000-0000-0000-0000-000000000015'::uuid,'branch_manager','branch','21000000-0000-0000-0000-00000000000a'),
  ('21000000-0000-0000-0000-000000000016'::uuid,'owner','tenant',null),
  ('21000000-0000-0000-0000-000000000017'::uuid,'trainee','tenant',null),
  ('21000000-0000-0000-0000-000000000018'::uuid,'finance_manager','tenant',null)
) as v(uid, role_code, scope, branch)
join public.roles r on r.code = v.role_code;

insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('21000000-0000-0000-0000-0000000000d1','21000000-0000-0000-0000-000000000001','person','Shared Customer','+201005551234');

-- One lead per branch. Alice owns Cairo's; Dave owns Alexandria's.
insert into public.leads (id, tenant_id, branch_id, department_id, owner_user_id, assigned_user_id,
                          lead_source_code, lead_status_code, title) values
  ('21000000-0000-0000-0000-0000000000e1','21000000-0000-0000-0000-000000000001',
   '21000000-0000-0000-0000-00000000000a','21000000-0000-0000-0000-0000000000c1',
   '21000000-0000-0000-0000-000000000011','21000000-0000-0000-0000-000000000011',
   'whatsapp','new','Cairo lead'),
  ('21000000-0000-0000-0000-0000000000e2','21000000-0000-0000-0000-000000000001',
   '21000000-0000-0000-0000-00000000000b','21000000-0000-0000-0000-0000000000c3',
   '21000000-0000-0000-0000-000000000014','21000000-0000-0000-0000-000000000014',
   'whatsapp','new','Alexandria lead');

-- A Cairo booking and its invoice, for the finance axis.
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                             booking_status_code, title, booking_reference) values
  ('21000000-0000-0000-0000-0000000000f1','21000000-0000-0000-0000-000000000001',
   '21000000-0000-0000-0000-00000000000a','21000000-0000-0000-0000-0000000000c1',
   '21000000-0000-0000-0000-0000000000d1','21000000-0000-0000-0000-000000000011',
   'draft','Cairo booking','BK-CAI-0001');

insert into public.invoices (id, tenant_id, customer_id, booking_id, invoice_number, invoice_date,
                             currency_code, total_amount, status_code) values
  ('21000000-0000-0000-0000-0000000000f2','21000000-0000-0000-0000-000000000001',
   '21000000-0000-0000-0000-0000000000d1','21000000-0000-0000-0000-0000000000f1',
   'INV-0001', current_date, 'EGP', 1000, 'draft');

-- A notification addressed to Alice, and nobody else.
insert into public.notifications (id, tenant_id, target_user_id, notification_type_code, title, body) values
  ('21000000-0000-0000-0000-0000000000f3','21000000-0000-0000-0000-000000000001',
   '21000000-0000-0000-0000-000000000011','lead_sla_warning','SLA','A lead needs attention');

-- ---------------------------------------------------------------------------------------------
-- From here on the caller is `authenticated`. RLS is now the only gate.
-- ---------------------------------------------------------------------------------------------
set local role authenticated;

-- Guard on the test itself: if this ever returns 0, the fixture -- not the model -- is what the
-- assertions below are measuring, and every "cannot see" result would be vacuously true.
select set_config('request.jwt.claims', '{"sub":"21000000-0000-0000-0000-0000000000a1"}', true);
select is((select count(*)::int from public.leads), 1,
  'ALICE sees exactly her own branch+department lead -- the fixture is visible at all, so the denials below are real');

select is((select count(*)::int from public.leads where id = '21000000-0000-0000-0000-0000000000e2'), 0,
  'ALICE (Cairo) cannot see the Alexandria lead -- branch isolation');

-- Department continuity: the rule the owner asked for by name. Bob is not assigned the lead and has
-- never touched it; he is simply in Alice's department, and Alice is absent.
select set_config('request.jwt.claims', '{"sub":"21000000-0000-0000-0000-0000000000a2"}', true);
select is((select count(*)::int from public.leads where id = '21000000-0000-0000-0000-0000000000e1'), 1,
  'BOB can continue his absent department colleague''s lead -- assignment is not sole visibility');
select is((select count(*)::int from public.leads where id = '21000000-0000-0000-0000-0000000000e2'), 0,
  'BOB still cannot see the other branch');

-- ...and the counterpart, without which the rule above would just mean "everyone in the branch".
select set_config('request.jwt.claims', '{"sub":"21000000-0000-0000-0000-0000000000a3"}', true);
select is((select count(*)::int from public.leads where id = '21000000-0000-0000-0000-0000000000e1'), 0,
  'CAROL (Cairo Operations) cannot see a Cairo SALES lead -- department is a real boundary inside a branch');

select set_config('request.jwt.claims', '{"sub":"21000000-0000-0000-0000-0000000000a4"}', true);
select is((select count(*)::int from public.leads where id = '21000000-0000-0000-0000-0000000000e1'), 0,
  'DAVE (Alexandria) cannot see the Cairo lead');
select is((select count(*)::int from public.leads), 1,
  'DAVE sees his own branch and nothing more');

-- Branch manager: every department in their branch, and no other branch.
select set_config('request.jwt.claims', '{"sub":"21000000-0000-0000-0000-0000000000a5"}', true);
select is((select count(*)::int from public.leads where id = '21000000-0000-0000-0000-0000000000e1'), 1,
  'MANAGER sees a lead in a department he does not belong to, because he governs the branch');
select is((select count(*)::int from public.leads), 1,
  'MANAGER does not cross into the other branch');

-- Owner: all branches, with branch identity preserved so branch-specific and consolidated reporting
-- are both derivable from the same rows.
select set_config('request.jwt.claims', '{"sub":"21000000-0000-0000-0000-0000000000a6"}', true);
select is((select count(*)::int from public.leads), 2,
  'OWNER sees both branches');
select is((select count(distinct branch_id)::int from public.leads), 2,
  'OWNER can still separate the branches -- branch identity survives as a reporting dimension');

-- Trainee: the restricted user the model has to actually restrict.
select set_config('request.jwt.claims', '{"sub":"21000000-0000-0000-0000-0000000000a7"}', true);
select is((select count(*)::int from public.leads), 0,
  'TRAINEE sees no leads at all -- no department permission, and none assigned to her');

-- Canon 05: the customer master is deliberately NOT branch-scoped, or a second branch could not find
-- a returning customer and would create the duplicate canon 05 forbids.
select set_config('request.jwt.claims', '{"sub":"21000000-0000-0000-0000-0000000000a4"}', true);
select is((select count(*)::int from public.customers where id = '21000000-0000-0000-0000-0000000000d1'), 1,
  'DAVE can see the shared customer master across branches (canon 05 cross-branch awareness)');
select is((select count(*)::int from public.bookings), 0,
  '...but not that customer''s bookings in the other branch -- "detailed event content from another branch is not shown"');

-- Finance is a separate axis from placement: Finn sits in no branch and must still reconcile.
select set_config('request.jwt.claims', '{"sub":"21000000-0000-0000-0000-0000000000a8"}', true);
select is((select count(*)::int from public.invoices), 1,
  'FINANCE MANAGER reads the invoice with no branch placement at all -- finance authority is not geographic');
select is((select count(*)::int from public.leads), 0,
  '...and that finance authority does not silently become operational visibility');

select set_config('request.jwt.claims', '{"sub":"21000000-0000-0000-0000-0000000000a1"}', true);
select is((select count(*)::int from public.invoices where id = '21000000-0000-0000-0000-0000000000f2'), 1,
  'ALICE reads the invoice for her own booking (canon 28: "assigned employee may view financial documents directly related to their booking")');

select set_config('request.jwt.claims', '{"sub":"21000000-0000-0000-0000-0000000000a4"}', true);
select is((select count(*)::int from public.invoices), 0,
  'DAVE cannot read another branch''s invoice');

-- Notifications are addressed correspondence, not tenant-wide broadcast.
select set_config('request.jwt.claims', '{"sub":"21000000-0000-0000-0000-0000000000a2"}', true);
select is((select count(*)::int from public.notifications), 0,
  'BOB cannot read a notification addressed to Alice, though they share a department');
select set_config('request.jwt.claims', '{"sub":"21000000-0000-0000-0000-0000000000a1"}', true);
select is((select count(*)::int from public.notifications), 1,
  'ALICE reads her own notification');

-- The whole model is worthless if a record created through a real RPC lands somewhere its author
-- cannot see. `app.create_complaint` is one of the four RPCs SPEC-137 repaired -- before the repair
-- it wrote a null ownership triple, which under a branch-scoped WITH CHECK is not merely invisible
-- but rejected outright. These four assertions are the regression guard for that whole class.
select lives_ok(
  $$select app.create_complaint('21000000-0000-0000-0000-0000000000d1','Late transfer','service_quality')$$,
  'ALICE creates a complaint through the real RPC as a real authenticated user under RLS');

select is((select count(*)::int from public.complaints where title = 'Late transfer'), 1,
  '...and can read back what she just created -- the record was filed under her branch, not into a hole');

select set_config('request.jwt.claims', '{"sub":"21000000-0000-0000-0000-0000000000a2"}', true);
select is((select count(*)::int from public.complaints where title = 'Late transfer'), 1,
  'BOB can act on it too, because customer service does not stop when one employee is away');

select set_config('request.jwt.claims', '{"sub":"21000000-0000-0000-0000-0000000000a4"}', true);
select is((select count(*)::int from public.complaints), 0,
  'DAVE cannot -- the complaint is Cairo''s business');

select * from finish();
rollback;
