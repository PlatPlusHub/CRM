-- ARCH-2: the same archive authority must govern entry on every selected surface.
create extension if not exists pgtap with schema extensions;

begin;
select plan(32);

insert into auth.users (id, email) values
    ('18200000-0000-0000-0000-0000000000a1', 'senior@archive.test'),
    ('18200000-0000-0000-0000-0000000000a2', 'owner@archive.test');
insert into public.tenants (id, name, slug, status)
values ('18200000-0000-0000-0000-000000000001', 'Archive entry test', 'archive-entry-test', 'active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '18200000-0000-0000-0000-000000000001', id, 'active'
from public.subscription_plans
where plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug)
values ('18200000-0000-0000-0000-00000000000a', '18200000-0000-0000-0000-000000000001', 'Cairo', 'archive-entry-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name)
values ('18200000-0000-0000-0000-00000000000b', '18200000-0000-0000-0000-000000000001', '18200000-0000-0000-0000-00000000000a', 'sales', 'Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id)
values
    ('18200000-0000-0000-0000-000000000011', '18200000-0000-0000-0000-000000000001', 'Senior', 'senior@archive.test', true, '18200000-0000-0000-0000-0000000000a1'),
    ('18200000-0000-0000-0000-000000000012', '18200000-0000-0000-0000-000000000001', 'Owner', 'owner@archive.test', true, '18200000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select tenant_id, id, '18200000-0000-0000-0000-00000000000a', '18200000-0000-0000-0000-00000000000b', true
from public.users where tenant_id = '18200000-0000-0000-0000-000000000001';
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '18200000-0000-0000-0000-000000000001', v.user_id, r.id, 'tenant'
from (values
    ('18200000-0000-0000-0000-000000000011'::uuid, 'senior_employee'),
    ('18200000-0000-0000-0000-000000000012'::uuid, 'owner')
) v(user_id, role_code)
join public.roles r on r.code = v.role_code;

insert into public.customers (id, tenant_id, customer_type_code, full_name)
values ('18200000-0000-0000-0000-0000000000c1', '18200000-0000-0000-0000-000000000001', 'person', 'Archive Test Customer');

-- Same archive inputs on each real entry shape. The task fixture stays in the allowed open state.
create temporary table archive_entry_cases (surface text primary key, statement text not null);
insert into archive_entry_cases values
    ('bookings', $sql$insert into public.bookings
        (id, tenant_id, branch_id, department_id, customer_id, owner_user_id, owner_branch_id,
         owner_department_id, booking_status_code, title, booking_reference, is_archived, archive_reason, archived_at, archived_by)
        values (%1$L, '18200000-0000-0000-0000-000000000001', '18200000-0000-0000-0000-00000000000a',
         '18200000-0000-0000-0000-00000000000b', '18200000-0000-0000-0000-0000000000c1',
         app.current_user_id(), '18200000-0000-0000-0000-00000000000a', '18200000-0000-0000-0000-00000000000b',
         'draft', 'Archive entry booking', %1$L, %2$L, %3$L, %4$L, %5$L)$sql$),
    ('customers', $sql$insert into public.customers
        (id, tenant_id, customer_type_code, full_name, is_archived, archive_reason, archived_at, archived_by)
        values (%1$L, '18200000-0000-0000-0000-000000000001', 'person', 'Archive entry customer', %2$L, %3$L, %4$L, %5$L)$sql$),
    ('passengers', $sql$insert into public.passengers
        (id, tenant_id, first_name, family_name, full_name, passenger_type_code, is_archived, archive_reason, archived_at, archived_by)
        values (%1$L, '18200000-0000-0000-0000-000000000001', 'Archive', 'Passenger', 'Archive Passenger',
         'adult', %2$L, %3$L, %4$L, %5$L)$sql$),
    ('suppliers', $sql$insert into public.suppliers
        (id, tenant_id, name, supplier_type_code, is_archived, archive_reason, archived_at, archived_by)
        values (%1$L, '18200000-0000-0000-0000-000000000001', 'Archive entry supplier ' || %1$L,
         'airline', %2$L, %3$L, %4$L, %5$L)$sql$),
    ('tasks', $sql$insert into public.tasks
        (id, tenant_id, owner_user_id, owner_department_id, owner_branch_id, task_type_code, task_status_code, title,
         is_archived, archive_reason, archived_at, archived_by)
        values (%1$L, '18200000-0000-0000-0000-000000000001', app.current_user_id(),
         '18200000-0000-0000-0000-00000000000b', '18200000-0000-0000-0000-00000000000a', 'follow_up', 'open',
         'Archive entry task', %2$L, %3$L, %4$L, %5$L)$sql$);
grant select on archive_entry_cases to authenticated;

select set_config('request.jwt.claims','{"sub":"18200000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select ok(app.has_permission('ASSIGN_SUPPLIER') and app.has_permission('CREATE_BOOKING')
          and app.has_permission('CREATE_BOOKING_ITEM') and app.has_permission('CREATE_TASK')
          and app.has_permission('CREATE_CUSTOMER') and not app.has_permission('ARCHIVE_RECORD'),
          'senior can create on all selected paths and has no archive authority');
select lives_ok(format(statement, '18200000-0000-0000-0000-000000000101', false, null, null, null),
                surface || ': ordinary creation succeeds') from archive_entry_cases order by surface;
select throws_ok(format(statement, '18200000-0000-0000-0000-000000000102', true, 'reported', null, null),
                 '42501', 'permission denied: ARCHIVE_RECORD',
                 surface || ': creating archived requires archive authority') from archive_entry_cases order by surface;
select throws_ok(format(statement, '18200000-0000-0000-0000-000000000103', false, 'reported', null, null),
                 '42501', 'permission denied: ARCHIVE_RECORD',
                 surface || ': an archive reason alone requires archive authority') from archive_entry_cases order by surface;
select throws_ok(format(statement, '18200000-0000-0000-0000-000000000104', false, null, '2020-01-01',
                  '18200000-0000-0000-0000-000000000012'),
                 '42501', 'archive metadata is set by the server',
                 surface || ': an active row cannot claim archive metadata') from archive_entry_cases order by surface;

select set_config('request.jwt.claims','{"sub":"18200000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select ok(app.has_permission('ARCHIVE_RECORD'), 'owner holds archive authority');
select lives_ok(format(statement, '18200000-0000-0000-0000-000000000105', true, 'approved', '2020-01-01',
                 '18200000-0000-0000-0000-000000000011'),
                surface || ': authorized creation may archive and supply a reason') from archive_entry_cases order by surface;
reset role;

select results_eq(
    format('select is_archived, archive_reason, archived_at = now(), archived_by from public.%I where id = %L',
           surface, '18200000-0000-0000-0000-000000000105'),
    $$values (true, 'approved'::text, true, '18200000-0000-0000-0000-000000000012'::uuid)$$,
    surface || ': archived actor and time come from the server'
) from archive_entry_cases order by surface;

select * from finish();
rollback;
