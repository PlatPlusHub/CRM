-- pgTAP: SPEC-214 / QUO-5, QUO-6, QUO-7, QUO-8 -- Batch 6 slice 14, `public.quotations`.
--
-- The table door may not give a quotation a state or a commercial term its lifecycle RPCs cannot.
-- `authenticated` holds table-level INSERT and UPDATE, so PostgREST serves this table beside
-- `app.create_quotation` / `app.advance_quotation` (BOOK-1), and before `20260924120000` the door
-- enforced the transition AUTHORITY and none of the lifecycle STATE.
--
-- ATTACK-CLASSES: AUTH DOOR STATE BUSINESS TENANT PRIVILEGE CONCURRENCY=N/A REPLAY=N/A
--   CONCURRENCY=N/A -- the guard reads no counter, lease or balance; the one set-level value, the
--     total, is maintained by `app.recompute_quotation_total`, which runs as `postgres` and so is
--     never judged by this guard (73 owns that derivation).
--   REPLAY=N/A -- nothing here is single-use; re-sending the same statement meets the same rule.
--   INPUT and OBSERVABILITY are NOT declared: the value CHECKs are 112's, and event parity for
--     direct-DML writes was not swept in this slice (the disposition row names it).
--
-- THE ACTORS are chosen so no other control can be the refuser. `emp` is an `employee` at `aal2`
-- holding CREATE_QUOTATION and carrying explicit DENY overrides on SEND_QUOTATION and
-- ACCEPT_QUOTATION -- every role that holds CREATE_QUOTATION also holds the other two, so a deny is
-- the only way to separate them. `mgr` is a `branch_manager` at `aal2` holding all three, so every
-- refusal it meets is the lifecycle rule and not a permission.
create extension if not exists pgtap with schema extensions;

begin;
select plan(30);

insert into auth.users (id, email) values
  ('12000000-0000-0000-0000-0000000000a1','emp@q120.test'),
  ('12000000-0000-0000-0000-0000000000a2','mgr@q120.test');
insert into public.tenants (id, name, slug, status) values
  ('12000000-0000-0000-0000-000000000001','Q120 Travel','q120-travel','active'),
  ('12000000-0000-0000-0000-000000000002','Q120 Other','q120-other','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active' from public.subscription_plans sp,
  unnest(array['12000000-0000-0000-0000-000000000001'::uuid,'12000000-0000-0000-0000-000000000002']) t
where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('12000000-0000-0000-0000-00000000000a','12000000-0000-0000-0000-000000000001','Cairo','q120-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('12000000-0000-0000-0000-0000000000c1','12000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('12000000-0000-0000-0000-000000000011','12000000-0000-0000-0000-000000000001','Emp','emp@q120.test',true,'12000000-0000-0000-0000-0000000000a1'),
  ('12000000-0000-0000-0000-000000000021','12000000-0000-0000-0000-000000000001','Mgr','mgr@q120.test',true,'12000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '12000000-0000-0000-0000-000000000001', u, '12000000-0000-0000-0000-00000000000a', '12000000-0000-0000-0000-0000000000c1', true
from unnest(array['12000000-0000-0000-0000-000000000011'::uuid,'12000000-0000-0000-0000-000000000021']) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '12000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000011', r.id, 'tenant' from public.roles r where r.code = 'employee';
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '12000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000021', r.id, 'tenant' from public.roles r where r.code = 'branch_manager';
insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect, reason)
select '12000000-0000-0000-0000-000000000001','12000000-0000-0000-0000-000000000011', p.id, 'deny', 'q120: separates creating from sending and accepting'
from public.permissions p where p.key in ('SEND_QUOTATION','ACCEPT_QUOTATION');
insert into public.customers (id, tenant_id, customer_type_code, full_name, first_registered_branch_id) values
  ('12000000-0000-0000-0000-0000000000d1','12000000-0000-0000-0000-000000000001','person','Buyer One','12000000-0000-0000-0000-00000000000a'),
  ('12000000-0000-0000-0000-0000000000d2','12000000-0000-0000-0000-000000000001','person','Buyer Two','12000000-0000-0000-0000-00000000000a');
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('12000000-0000-0000-0000-0000000000e1','12000000-0000-0000-0000-000000000002','person','Foreign Buyer');

-- A direct INSERT of a quotation with the given status, total and customer, owned by `emp`.
create function pg_temp.q120_insert(p_status text, p_number text, p_total numeric default 0,
                                    p_customer uuid default '12000000-0000-0000-0000-0000000000d1',
                                    p_tenant uuid default '12000000-0000-0000-0000-000000000001')
returns text language sql as $$
  select format($f$insert into public.quotations (tenant_id, customer_id, owner_user_id, owner_branch_id,
      owner_department_id, quotation_status_code, quotation_number, currency_code, total_amount)
    values (%L, %L, '12000000-0000-0000-0000-000000000011', '12000000-0000-0000-0000-00000000000a',
      '12000000-0000-0000-0000-0000000000c1', %L, %L, 'EGP', %s)$f$,
    p_tenant, p_customer, p_status, p_number, p_total)
$$;
grant execute on function pg_temp.q120_insert(text, text, numeric, uuid, uuid) to authenticated;

-- =============================================================================================
-- 1-3. THE ACTOR, and the legitimate doors that must stay open.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"12000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;

select ok(app.has_permission('CREATE_QUOTATION') and not app.has_permission('SEND_QUOTATION')
          and not app.has_permission('ACCEPT_QUOTATION'),
  'POSITIVE CONTROL: emp holds CREATE_QUOTATION and is DENIED SEND_QUOTATION and ACCEPT_QUOTATION, so every refusal of emp below that names the lifecycle is the lifecycle rule and not a missing permission');

select lives_ok($$select app.create_quotation('12000000-0000-0000-0000-0000000000d1','EGP',null,null,'Q120-G1')$$,
  'POSITIVE CONTROL: the RPC creates a draft');

select lives_ok(pg_temp.q120_insert('draft','Q120-EMPTY'),
  'POSITIVE CONTROL: a direct INSERT of an ordinary empty draft still works -- the door is narrowed to the lifecycle, not closed');

-- =============================================================================================
-- 4-6. QUO-5 and QUO-7 at birth.
-- =============================================================================================
select throws_ok(pg_temp.q120_insert('accepted','Q120-ACC'),
  '23514', 'a quotation is created as a draft (canon 26); it cannot be created already accepted -- use app.advance_quotation',
  'QUO-5: a user DENIED ACCEPT_QUOTATION can no longer create a quotation born accepted -- before 20260924120000 it stored one with no items and no event, and app.create_booking produced a booking from it');

select throws_ok(pg_temp.q120_insert('sent','Q120-SNT'),
  '23514', 'a quotation is created as a draft (canon 26); it cannot be created already sent -- use app.advance_quotation',
  'QUO-5: nor one born sent, which skipped SEND_QUOTATION and the at-least-one-item rule together');

select throws_ok(pg_temp.q120_insert('draft','Q120-TOT', 50000),
  '23514', 'a quotation''s total is the sum of its items and a new quotation has none; it cannot be created at 50000.0000',
  'QUO-7: nor a draft born with a total of 50,000 and no lines');

-- =============================================================================================
-- 7-12. The derived total on a draft, and the terms fixed at creation.
-- =============================================================================================
select lives_ok($$select app.add_quotation_item((select id from public.quotations where quotation_number = 'Q120-G1'), 'hotel', 10000, 1)$$,
  'POSITIVE CONTROL: the RPC adds a line');

select lives_ok($$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, currency_code, unit_price, quantity, total_amount)
                  select tenant_id, id, 'hotel', 'EGP', 500, 1, 500 from public.quotations where quotation_number = 'Q120-G1'$$,
  'POSITIVE CONTROL: a direct line on a draft is still accepted -- the header it moves is rewritten by the definer path, not by the caller');

select is((select total_amount from public.quotations where quotation_number = 'Q120-G1'), 10500::numeric,
  'PRIVILEGE, POSITIVE: a direct line still moves the header through app.recompute_quotation_total, the definer path this guard lets through as postgres -- 10,000 + 500');

select throws_ok($$update public.quotations set total_amount = 1 where quotation_number = 'Q120-G1'$$,
  '23514', 'quotation Q120-G1 total is the sum of its items and is maintained by them; change the items instead',
  'QUO-7: the header total can no longer be asserted against its lines -- before, 1 stood against 10,500');

select throws_ok($$update public.quotations set currency_code = 'USD' where quotation_number = 'Q120-G1'$$,
  '23514', 'quotation Q120-G1 keeps the customer and currency it was created with; create a new quotation instead',
  'QUO-6: the currency is fixed at creation even on a draft -- its lines carry the currency they were priced in, and nothing re-denominates them');

select lives_ok($$update public.quotations set valid_until = now() + interval '14 days' where quotation_number = 'Q120-G1'$$,
  'POSITIVE CONTROL: an ordinary header edit on a draft (validity) is untouched');

-- =============================================================================================
-- 13-14. QUO-8: an empty draft cannot be sent through the table, as it cannot through the RPC.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"12000000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
set local role authenticated;

select throws_ok($$update public.quotations set quotation_status_code = 'sent' where quotation_number = 'Q120-EMPTY'$$,
  '23514', 'a quotation needs at least one item before it can be sent',
  'QUO-8: a SEND_QUOTATION holder cannot send an EMPTY draft directly -- the transition itself is authorized, so only the lifecycle rule refuses it');

select throws_ok($$select app.advance_quotation((select id from public.quotations where quotation_number = 'Q120-EMPTY'), 'sent', 'x')$$,
  'P0001', 'a quotation needs at least one item before it can be sent',
  'PARITY: the rule and its words are the RPC''s own, copied rather than invented');

-- =============================================================================================
-- 15-18. After the offer has left the building.
-- =============================================================================================
select lives_ok($$select app.advance_quotation((select id from public.quotations where quotation_number = 'Q120-G1'), 'sent', 'emailed')$$,
  'POSITIVE CONTROL: the RPC sends a quotation that has lines');

reset role;
select set_config('request.jwt.claims','{"sub":"12000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select throws_ok($$update public.quotations set quotation_status_code = 'accepted' where quotation_number = 'Q120-G1'$$,
  '42501', 'permission denied: ACCEPT_QUOTATION',
  'AUTH, CONTRAST: the UPDATE door already held -- the same denied user asserting the same acceptance by UPDATE is refused by the transition authority; it was the INSERT door that had no entry rule');
reset role;
select set_config('request.jwt.claims','{"sub":"12000000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
set local role authenticated;

select throws_ok($$update public.quotations set customer_id = '12000000-0000-0000-0000-0000000000d2' where quotation_number = 'Q120-G1'$$,
  '23514', 'quotation Q120-G1 keeps the customer and currency it was created with; create a new quotation instead',
  'QUO-6: a SENT quotation cannot be re-pointed at another customer -- before, the booking it later produced went to a customer the offer was never sent to');

select throws_ok($$update public.quotations set total_amount = 1 where quotation_number = 'Q120-G1'$$,
  '23514', 'quotation Q120-G1 total is the sum of its items and is maintained by them; change the items instead',
  'QUO-7: nor can a SENT quotation''s total be rewritten -- before, the forged figure was what app.advance_quotation copied into the next event');

-- =============================================================================================
-- 19-22. The legitimate revision loop and acceptance, and the terms after acceptance.
-- =============================================================================================
select lives_ok($$select app.advance_quotation((select id from public.quotations where quotation_number = 'Q120-G1'), 'rejected', 'too dear');
                  select app.advance_quotation((select id from public.quotations where quotation_number = 'Q120-G1'), 'draft', 'revising')$$,
  'POSITIVE CONTROL: rejected -> draft, the revision loop canon 26 defines');

select lives_ok($$update public.quotations set quotation_status_code = 'sent' where quotation_number = 'Q120-G1'$$,
  'POSITIVE CONTROL: a SEND_QUOTATION holder may still send a draft WITH lines directly -- the direct transition door is preserved, only its missing precondition is added');

select lives_ok($$select app.advance_quotation((select id from public.quotations where quotation_number = 'Q120-G1'), 'accepted', 'customer signed')$$,
  'POSITIVE CONTROL: the RPC accepts it');

select throws_ok($$update public.quotations set currency_code = 'SAR' where quotation_number = 'Q120-G1'$$,
  '23514', 'quotation Q120-G1 keeps the customer and currency it was created with; create a new quotation instead',
  'QUO-6: an ACCEPTED quotation cannot be re-denominated -- before, 10,500 EGP of lines stood under a SAR header');

-- =============================================================================================
-- 23-24. BUSINESS consequence: the booking follows the quotation the customer actually accepted.
-- =============================================================================================
select lives_ok($$select app.create_booking(p_quotation_id => (select id from public.quotations where quotation_number = 'Q120-G1'),
                   p_title => 'Q120', p_branch_id => '12000000-0000-0000-0000-00000000000a',
                   p_department_id => '12000000-0000-0000-0000-0000000000c1')$$,
  'POSITIVE CONTROL: a genuinely accepted quotation still produces a booking');

select is((select string_agg(b.customer_id::text || '/' || q.quotation_number, ',')
             from public.bookings b join public.quotations q on q.id = b.quotation_id
            where b.tenant_id = '12000000-0000-0000-0000-000000000001'),
  '12000000-0000-0000-0000-0000000000d1/Q120-G1',
  'BUSINESS: the tenant''s only quotation-backed booking is Q120-G1''s, for the customer it was created and sent for -- no booking stands on a forged acceptance or a re-pointed customer');
reset role;

-- =============================================================================================
-- 25-26. TENANT. Not this guard's work -- RLS and the composite FKs -- asserted so the boundary is
-- proven here rather than assumed.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"12000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select throws_ok(pg_temp.q120_insert('draft','Q120-X1', 0, '12000000-0000-0000-0000-0000000000e1', '12000000-0000-0000-0000-000000000002'),
  '42501', 'new row violates row-level security policy for table "quotations"',
  'TENANT: a draft planted in another tenant is refused by row-level security');
select throws_ok(pg_temp.q120_insert('draft','Q120-X2', 0, '12000000-0000-0000-0000-0000000000e1'),
  '23503', 'insert or update on table "quotations" violates foreign key constraint "quotations_customer_id_fkey"',
  'TENANT: a draft in my tenant for another tenant''s customer is refused by the composite foreign key');
reset role;

-- =============================================================================================
-- 27. PRIVILEGE: the guard runs as the caller, which is what makes `current_user` name the caller.
-- =============================================================================================
select ok(
  not (select prosecdef from pg_proc where oid = 'app.guard_quotation_integrity'::regproc)
  and not has_function_privilege('public', 'app.guard_quotation_integrity()', 'EXECUTE')
  and (select count(*) = 1 from pg_trigger t
        where t.tgrelid = 'public.quotations'::regclass and not t.tgisinternal
          and t.tgfoid = 'app.guard_quotation_integrity'::regproc
          and (t.tgtype & 2) <> 0 and (t.tgtype & 4) <> 0 and (t.tgtype & 16) <> 0),
  'PRIVILEGE: app.guard_quotation_integrity is SECURITY INVOKER, grants PUBLIC no EXECUTE, and fires BEFORE INSERT OR UPDATE on public.quotations exactly once');

-- =============================================================================================
-- 28-30. LOAD-BEARING: remove the guard and QUO-5 is back; restore it and it is gone.
-- TEST-3: the in-savepoint assertion is re-asserted after the rollback so it is counted.
-- =============================================================================================
savepoint q120_mutation;
drop trigger quotations_guard_integrity on public.quotations;
select set_config('request.jwt.claims','{"sub":"12000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select lives_ok(pg_temp.q120_insert('accepted','Q120-MUT'),
  'MUTATION: with quotations_guard_integrity dropped, the denied user''s quotation born accepted is stored again -- so this trigger is what closes QUO-5');
reset role;
rollback to savepoint q120_mutation;

select set_config('request.jwt.claims','{"sub":"12000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select throws_ok(pg_temp.q120_insert('accepted','Q120-MUT'),
  '23514', 'a quotation is created as a draft (canon 26); it cannot be created already accepted -- use app.advance_quotation',
  'RESTORED: with the mutation rolled back the identical insert is refused again');
reset role;

select is((select count(*)::int from public.quotations
            where tenant_id = '12000000-0000-0000-0000-000000000001' and quotation_status_code <> 'draft'
              and not exists (select 1 from public.quotation_items qi where qi.quotation_id = quotations.id)),
  0,
  'NO RESIDUE: no quotation in the tenant stands outside draft without lines');

select * from finish();
rollback;
