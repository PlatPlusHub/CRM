-- pgTAP: SPEC-215 / SUP-5 -- Batch 6 slice 15, `public.suppliers`.
--
-- A supplier is a payee, and `suppliers` has no creator column, so the `supplier_created` event is
-- the only record of who added one to the supplier master. `authenticated` holds table-level INSERT
-- and PostgREST serves it beside `app.create_supplier`; before `20260924130000` only the RPC
-- emitted the event, and a supplier created at the table door was silent.
--
-- ATTACK-CLASSES: OBSERVABILITY DOOR TENANT STATE PRIVILEGE CONCURRENCY=N/A REPLAY=N/A
--   CONCURRENCY=N/A -- the emitter is one AFTER ROW call per inserted row and reads nothing another
--     transaction can move.
--   REPLAY=N/A -- nothing here is single-use; a second INSERT is a second supplier and is recorded.
--   AUTH, INPUT and BUSINESS are NOT declared. They were probed in this slice and are not pinned:
--     both doors give the same answer at `aal1`; a blank name and a case-variant duplicate reach
--     the table door, but a name is freely editable there and the RPC itself admits a near-variant,
--     so neither is a rule this file should freeze. A row born archived is ARCH-2's.
--
-- THE ACTORS. `senior` is a `senior_employee` at `aal2`: it holds ASSIGN_SUPPLIER and holds neither
-- ARCHIVE_RECORD nor MANAGE_SUPPLIER_CREDIT, so it can create a supplier and every refusal it meets
-- below is the named control. `owner` holds ARCHIVE_RECORD.
create extension if not exists pgtap with schema extensions;

begin;
select plan(21);

insert into auth.users (id, email) values
  ('12100000-0000-0000-0000-0000000000a1','senior@s121.test'),
  ('12100000-0000-0000-0000-0000000000a2','owner@s121.test');
insert into public.tenants (id, name, slug, status) values
  ('12100000-0000-0000-0000-000000000001','S121 Travel','s121-travel','active'),
  ('12100000-0000-0000-0000-000000000002','S121 Other','s121-other','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active' from public.subscription_plans sp,
  unnest(array['12100000-0000-0000-0000-000000000001'::uuid,'12100000-0000-0000-0000-000000000002']) t
where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('12100000-0000-0000-0000-00000000000a','12100000-0000-0000-0000-000000000001','Cairo','s121-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('12100000-0000-0000-0000-0000000000c1','12100000-0000-0000-0000-000000000001','12100000-0000-0000-0000-00000000000a','management','Exec');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('12100000-0000-0000-0000-000000000011','12100000-0000-0000-0000-000000000001','Senior','senior@s121.test',true,'12100000-0000-0000-0000-0000000000a1'),
  ('12100000-0000-0000-0000-000000000012','12100000-0000-0000-0000-000000000001','Owner','owner@s121.test',true,'12100000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '12100000-0000-0000-0000-000000000001', u, '12100000-0000-0000-0000-00000000000a', '12100000-0000-0000-0000-0000000000c1', true
from unnest(array['12100000-0000-0000-0000-000000000011'::uuid,'12100000-0000-0000-0000-000000000012']) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '12100000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('12100000-0000-0000-0000-000000000011'::uuid,'senior_employee'),
             ('12100000-0000-0000-0000-000000000012'::uuid,'owner')) v(u, rc)
join public.roles r on r.code = v.rc;

-- Written as `postgres`, with no session: the platform path, recorded with a null actor (16).
insert into public.suppliers (id, tenant_id, name, supplier_type_code) values
  ('12100000-0000-0000-0000-0000000000e1','12100000-0000-0000-0000-000000000001','Nile Air','airline');

-- One line per supplier named `p_name` in the tenant: event count / actor / payload.
create function pg_temp.s121_trace(p_name text) returns text language sql as $$
  select count(e.id)::text || '/' || coalesce(max(e.actor_user_id::text), '-') || '/' || coalesce(max(e.payload::text), '-')
  from public.suppliers s
  left join public.events e on e.entity_id = s.id and e.event_type_code = 'supplier_created'
  where s.tenant_id = '12100000-0000-0000-0000-000000000001' and s.name = p_name
$$;
grant execute on function pg_temp.s121_trace(text) to authenticated;

-- =============================================================================================
-- 1-3. THE ACTOR, and the RPC path: still exactly one event, as before.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"12100000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;

select ok(app.has_permission('ASSIGN_SUPPLIER') and not app.has_permission('ARCHIVE_RECORD')
          and not app.has_permission('MANAGE_SUPPLIER_CREDIT'),
  'PREMISE: senior holds ASSIGN_SUPPLIER and neither ARCHIVE_RECORD nor MANAGE_SUPPLIER_CREDIT');

select lives_ok($$select app.create_supplier('  Rpc Air ', 'airline')$$,
  'POSITIVE CONTROL: the RPC creates a supplier');

select is(pg_temp.s121_trace('Rpc Air'),
  '1/12100000-0000-0000-0000-000000000011/{"name": "Rpc Air", "supplier_type_code": "airline"}',
  'DOOR: the RPC path records exactly ONE supplier_created, with the caller as actor and the RPC''s own payload -- the RPC no longer emits it itself, so it is not recorded twice');

-- =============================================================================================
-- 4-6. SUP-5: the table door.
-- =============================================================================================
select lives_ok($$insert into public.suppliers (tenant_id, name, supplier_type_code, created_at)
                  values ('12100000-0000-0000-0000-000000000001', 'Shell Air', 'airline', '2019-01-01')$$,
  'POSITIVE CONTROL: the table door still creates a supplier -- it is recorded, not closed');

select is(pg_temp.s121_trace('Shell Air'),
  '1/12100000-0000-0000-0000-000000000011/{"name": "Shell Air", "supplier_type_code": "airline"}',
  'SUP-5: a supplier created at the table door records supplier_created naming its creator -- before 20260924130000 this row had zero events and nothing anywhere said who added it');

select ok((select e.created_at >= now() - interval '1 minute' from public.events e
             join public.suppliers s on s.id = e.entity_id
            where s.name = 'Shell Air' and e.event_type_code = 'supplier_created')
          and (select created_at < '2020-01-01' from public.suppliers where name = 'Shell Air'),
  'SUP-5: the ledger carries the true creation time while the row still says 2019 -- the backdate is contradicted rather than silent');

-- =============================================================================================
-- 7-10. What is not recorded, deliberately.
-- =============================================================================================
select lives_ok($$update public.suppliers set phone = '+20 100 000 1210' where name = 'Shell Air'$$,
  'POSITIVE CONTROL: the designed edit door still edits an ordinary field');

select is(pg_temp.s121_trace('Shell Air'),
  '1/12100000-0000-0000-0000-000000000011/{"name": "Shell Air", "supplier_type_code": "airline"}',
  'an edit records no second supplier_created -- canon 27 has no supplier-update event and this migration invents none');

select throws_ok($$insert into public.suppliers (tenant_id, name, supplier_type_code, credit_limit_amount, credit_limit_currency_code)
                   values ('12100000-0000-0000-0000-000000000001', 'Ceiling Air', 'airline', 5000, 'EGP')$$,
  '42501', 'permission denied: MANAGE_SUPPLIER_CREDIT',
  'PRIVILEGE: the credit guard still refuses a ceiling from a non-holder at the door');

select is((select count(*)::int from public.events
            where event_type_code = 'supplier_created' and payload ->> 'name' = 'Ceiling Air'),
  0,
  'a refused creation leaves no supplier_created behind');

-- =============================================================================================
-- 11-15. TENANT and STATE. Not the emitter's work -- RLS and app.enforce_archive_authority --
-- asserted so the boundaries swept in this slice are proven here rather than assumed.
-- =============================================================================================
select throws_ok($$update public.suppliers set tenant_id = '12100000-0000-0000-0000-000000000002' where name = 'Shell Air'$$,
  '42501', 'new row violates row-level security policy for table "suppliers"',
  'TENANT: a supplier cannot be moved into another tenant');

select throws_ok($$insert into public.suppliers (tenant_id, name, supplier_type_code)
                   values ('12100000-0000-0000-0000-000000000002', 'Planted Air', 'airline')$$,
  '42501', 'new row violates row-level security policy for table "suppliers"',
  'TENANT: nor planted in one');

select throws_ok($$update public.suppliers set is_archived = true, archive_reason = 'x' where name = 'Shell Air'$$,
  '42501', 'permission denied: ARCHIVE_RECORD',
  'STATE: archiving a supplier at the edit door costs ARCHIVE_RECORD');
reset role;

select set_config('request.jwt.claims','{"sub":"12100000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
set local role authenticated;
select lives_ok($$update public.suppliers set is_archived = true, archive_reason = 'duplicate',
                         archived_at = '2001-01-01', archived_by = '12100000-0000-0000-0000-000000000011'
                   where name = 'Shell Air'$$,
  'POSITIVE CONTROL: an ARCHIVE_RECORD holder archives it');
reset role;

select is((select archived_by::text || '/' || (archived_at >= now() - interval '1 minute')::text
             from public.suppliers where name = 'Shell Air'),
  '12100000-0000-0000-0000-000000000012/true',
  'STATE: the archiver and the time are the server''s, not the statement''s -- the forged senior and 2001 were overwritten');

-- =============================================================================================
-- 16-18. The platform path and the emitter's own privileges.
-- =============================================================================================
select is(pg_temp.s121_trace('Nile Air'),
  '1/-/{"name": "Nile Air", "supplier_type_code": "airline"}',
  'the session-less platform path is recorded too, with a null actor -- what a system act looks like on this ledger');

select ok(
  (select prosecdef from pg_proc where oid = 'app.emit_supplier_created'::regproc)
  and not has_function_privilege('public', 'app.emit_supplier_created()', 'EXECUTE')
  and not has_function_privilege('authenticated', 'app.emit_supplier_created()', 'EXECUTE')
  and (select count(*) = 1 from pg_trigger t
        where t.tgrelid = 'public.suppliers'::regclass and not t.tgisinternal
          and t.tgfoid = 'app.emit_supplier_created'::regproc
          and (t.tgtype & 2) = 0 and (t.tgtype & 4) <> 0 and (t.tgtype & 8) = 0 and (t.tgtype & 16) = 0),
  'PRIVILEGE: app.emit_supplier_created is SECURITY DEFINER, executable by neither PUBLIC nor authenticated, and fires AFTER INSERT only, exactly once');

select ok(not has_table_privilege('authenticated', 'public.suppliers', 'DELETE'),
  'PRIVILEGE: authenticated holds no DELETE here, so there is no unrecorded door that removes a supplier');

-- =============================================================================================
-- 19-21. LOAD-BEARING: remove the emitter and the door is silent again; restore it and it records.
-- TEST-3: the in-savepoint assertion is re-asserted after the rollback so it is counted.
-- =============================================================================================
savepoint s121_mutation;
drop trigger suppliers_emit_created on public.suppliers;
select set_config('request.jwt.claims','{"sub":"12100000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
insert into public.suppliers (tenant_id, name, supplier_type_code)
values ('12100000-0000-0000-0000-000000000001', 'Mutant Air', 'airline');
select is(pg_temp.s121_trace('Mutant Air'), '0/-/-',
  'MUTATION: with suppliers_emit_created dropped, a supplier created at the door is silent again -- so this trigger is what closes SUP-5');
reset role;
rollback to savepoint s121_mutation;

select set_config('request.jwt.claims','{"sub":"12100000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
insert into public.suppliers (tenant_id, name, supplier_type_code)
values ('12100000-0000-0000-0000-000000000001', 'Mutant Air', 'airline');
select is(pg_temp.s121_trace('Mutant Air'),
  '1/12100000-0000-0000-0000-000000000011/{"name": "Mutant Air", "supplier_type_code": "airline"}',
  'RESTORED: with the mutation rolled back the identical insert is recorded again');
reset role;

select is((select count(*)::int from public.suppliers s
            where s.tenant_id = '12100000-0000-0000-0000-000000000001'
              and (select count(*) from public.events e
                    where e.entity_id = s.id and e.event_type_code = 'supplier_created') <> 1),
  0,
  'COMPLETENESS: every supplier in the tenant carries exactly one supplier_created');

select * from finish();
rollback;
