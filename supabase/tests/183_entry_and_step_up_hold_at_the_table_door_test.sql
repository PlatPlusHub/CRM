-- B6-EXIT bundle A: ARCH-2 archive authority at entry on leads, quotations, booking_items and
-- invoices; STEPUP-1 step-up on campaign_daily_metrics and exchange_rate_adjustments; ENTRY-1
-- booking items enter at 'draft' with no lifecycle stamp. Each refused case below passed at 73b02a1.
create extension if not exists pgtap with schema extensions;

begin;
select plan(30);

insert into auth.users (id, email) values
    ('18300000-0000-0000-0000-0000000000a1', 'owner@entry183.test'),
    ('18300000-0000-0000-0000-0000000000a2', 'finance@entry183.test'),
    ('18300000-0000-0000-0000-0000000000a3', 'emp@entry183.test');
insert into public.tenants (id, name, slug, status)
values ('18300000-0000-0000-0000-000000000001', 'Entry 183 Travel', 'entry-183', 'active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '18300000-0000-0000-0000-000000000001', id, 'active'
from public.subscription_plans where plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug)
values ('18300000-0000-0000-0000-00000000000a', '18300000-0000-0000-0000-000000000001', 'HQ', 'entry-183-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name)
values ('18300000-0000-0000-0000-00000000000b', '18300000-0000-0000-0000-000000000001',
        '18300000-0000-0000-0000-00000000000a', 'management', 'Exec');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
    ('18300000-0000-0000-0000-000000000011', '18300000-0000-0000-0000-000000000001', 'Owner', 'owner@entry183.test', true, '18300000-0000-0000-0000-0000000000a1'),
    ('18300000-0000-0000-0000-000000000012', '18300000-0000-0000-0000-000000000001', 'Finance', 'finance@entry183.test', true, '18300000-0000-0000-0000-0000000000a2'),
    ('18300000-0000-0000-0000-000000000013', '18300000-0000-0000-0000-000000000001', 'Emp', 'emp@entry183.test', true, '18300000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select tenant_id, id, '18300000-0000-0000-0000-00000000000a', '18300000-0000-0000-0000-00000000000b', true
from public.users where tenant_id = '18300000-0000-0000-0000-000000000001';
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '18300000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('18300000-0000-0000-0000-000000000011'::uuid, 'owner'),
             ('18300000-0000-0000-0000-000000000012'::uuid, 'finance_manager'),
             ('18300000-0000-0000-0000-000000000013'::uuid, 'employee')) v(u, rc)
join public.roles r on r.code = v.rc;

insert into public.marketing_campaigns (id, tenant_id, platform_code, campaign_name, status_code)
values ('18300000-0000-0000-0000-0000000000cc', '18300000-0000-0000-0000-000000000001', 'google_ads', 'Umrah Q3', 'active');
insert into public.campaign_daily_metrics (id, tenant_id, marketing_campaign_id, metric_date, spend_amount, currency_code, impressions, clicks, revenue_amount)
values ('18300000-0000-0000-0000-0000000000dd', '18300000-0000-0000-0000-000000000001',
        '18300000-0000-0000-0000-0000000000cc', date '2026-08-01', 10, 'EGP', 100, 5, 0);
insert into public.customers (id, tenant_id, customer_type_code, full_name)
values ('18300000-0000-0000-0000-0000000000d1', '18300000-0000-0000-0000-000000000001', 'person', 'Customer');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, booking_status_code, title, booking_reference, owner_user_id) values
    ('18300000-0000-0000-0000-0000000000b1', '18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-00000000000a',
     '18300000-0000-0000-0000-00000000000b', '18300000-0000-0000-0000-0000000000d1', 'confirmed', 'Trip', 'BR-ENTRY183-1',
     '18300000-0000-0000-0000-000000000011'),
    ('18300000-0000-0000-0000-0000000000b2', '18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-00000000000a',
     '18300000-0000-0000-0000-00000000000b', '18300000-0000-0000-0000-0000000000d1', 'draft', 'EmpTrip', 'BR-ENTRY183-2',
     '18300000-0000-0000-0000-000000000013');
insert into public.suppliers (id, tenant_id, name, supplier_type_code)
values ('18300000-0000-0000-0000-0000000000e1', '18300000-0000-0000-0000-000000000001', 'Air', 'airline');
insert into public.booking_items (id, tenant_id, booking_id, supplier_id, service_type_code, currency_code, cost_amount, selling_amount, base_status_code)
values ('18300000-0000-0000-0000-0000000000f1', '18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000b1',
        '18300000-0000-0000-0000-0000000000e1', 'flight_ticket', 'USD', 400, 500, 'confirmed');
insert into public.exchange_rates (id, tenant_id, from_currency_code, to_currency_code, rate, effective_at) values
    ('18300000-0000-0000-0000-0000000000ea', '18300000-0000-0000-0000-000000000001', 'USD', 'EGP', 48.0, now() - interval '2 days'),
    ('18300000-0000-0000-0000-0000000000eb', '18300000-0000-0000-0000-000000000001', 'USD', 'EGP', 49.5, now() - interval '1 day');

-- One entry shape per ARCH-2 surface the employee can create: %1 id, %2 is_archived, %3 reason,
-- %4 archived_at, %5 archived_by.
create temporary table entry_cases (surface text primary key, statement text not null);
insert into entry_cases values
    ('booking_items', $sql$insert into public.booking_items
        (id, tenant_id, booking_id, service_type_code, currency_code, base_status_code, owner_user_id,
         is_archived, archive_reason, archived_at, archived_by)
        values (%1$L, '18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000b2', 'flight_ticket',
         'USD', 'draft', '18300000-0000-0000-0000-000000000013', %2$L, %3$L, %4$L, %5$L)$sql$),
    ('leads', $sql$insert into public.leads
        (id, tenant_id, branch_id, department_id, lead_source_code, lead_status_code, title,
         is_archived, archive_reason, archived_at, archived_by)
        values (%1$L, '18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-00000000000a',
         '18300000-0000-0000-0000-00000000000b', 'direct_call', 'new', 'Entry lead', %2$L, %3$L, %4$L, %5$L)$sql$),
    ('quotations', $sql$insert into public.quotations
        (id, tenant_id, customer_id, owner_user_id, quotation_status_code, quotation_number, currency_code,
         is_archived, archive_reason, archived_at, archived_by)
        values (%1$L, '18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000d1',
         '18300000-0000-0000-0000-000000000013', 'draft', 'Q-' || %1$L, 'EGP', %2$L, %3$L, %4$L, %5$L)$sql$);
grant select on entry_cases to authenticated;

-- ENTRY-1 cases: each is an entry the RPC door never writes.
create temporary table item_entry_cases (label text primary key, cols text not null, vals text not null);
insert into item_entry_cases values
    ('born in_progress past a finance gate', 'base_status_code, finance_approval_required', $v$'in_progress', true$v$),
    ('born completed and backdated',         'base_status_code, completed_at',              $v$'completed', now() - interval '400 days'$v$),
    ('draft with a completion stamp',        'base_status_code, completed_at',              $v$'draft', now()$v$),
    ('draft with a cancellation stamp',      'base_status_code, cancelled_at',              $v$'draft', now()$v$),
    ('draft with a no-show stamp',           'base_status_code, no_show_at',                $v$'draft', now()$v$);
grant select on item_entry_cases to authenticated;

set local role authenticated;

-- ARCH-2: the employee holds create but not archive authority.
select set_config('request.jwt.claims', '{"sub":"18300000-0000-0000-0000-0000000000a3","aal":"aal1"}', true);
select ok(app.has_permission('CREATE_LEAD') and app.has_permission('CREATE_QUOTATION')
          and app.has_permission('CREATE_BOOKING_ITEM') and not app.has_permission('ARCHIVE_RECORD'),
          'employee creates leads, quotations and booking items without archive authority');
select throws_ok(format(statement, '18300000-0000-0000-0000-000000000101', true, 'x', null, null),
                 '42501', 'permission denied: ARCHIVE_RECORD',
                 surface || ': creating archived requires archive authority') from entry_cases order by surface;
select throws_ok(format(statement, '18300000-0000-0000-0000-000000000102', false, null, now(),
                        '18300000-0000-0000-0000-000000000011'),
                 '42501', 'archive metadata is set by the server',
                 surface || ': an active row cannot claim a forged archiver') from entry_cases order by surface;
select lives_ok(format(statement, '18300000-0000-0000-0000-000000000103', false, null, null, null),
                surface || ': ordinary creation still succeeds') from entry_cases order by surface;

-- ARCH-2 invoices: a finance user who holds archive authority still cannot author the stamp.
select set_config('request.jwt.claims', '{"sub":"18300000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
select throws_ok($$insert into public.invoices (tenant_id, customer_id, invoice_number, invoice_date, currency_code, total_amount, status_code, archived_by)
                   values ('18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000d1', 'INV-183-A', current_date, 'EGP', 10, 'draft',
                           '18300000-0000-0000-0000-000000000011')$$,
                 '42501', 'archive metadata is set by the server', 'invoices: an active row cannot claim a forged archiver');
select lives_ok($$insert into public.invoices (id, tenant_id, customer_id, invoice_number, invoice_date, currency_code, total_amount, status_code, is_archived, archived_by, archived_at)
                  values ('18300000-0000-0000-0000-000000000201', '18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000d1', 'INV-183-B',
                          current_date, 'EGP', 10, 'draft', true, '18300000-0000-0000-0000-000000000011', now() - interval '1 year')$$,
                'invoices: an authorized archived creation is accepted');

select set_config('request.jwt.claims', '{"sub":"18300000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
select lives_ok(format(statement, '18300000-0000-0000-0000-000000000104', true, 'approved', '2020-01-01',
                       '18300000-0000-0000-0000-000000000013'),
                'leads: an archive holder may create archived with a reason')
from entry_cases where surface = 'leads';
reset role;

select results_eq(
    $$select archived_by, archived_at = now() from public.invoices where id = '18300000-0000-0000-0000-000000000201'$$,
    $$values ('18300000-0000-0000-0000-000000000012'::uuid, true)$$,
    'invoices: the archiver and time come from the server, not the forged and backdated input');
select results_eq(
    $$select is_archived, archive_reason, archived_by, archived_at = now() from public.leads where id = '18300000-0000-0000-0000-000000000104'$$,
    $$values (true, 'approved'::text, '18300000-0000-0000-0000-000000000011'::uuid, true)$$,
    'leads: the archiver and time come from the server');

set local role authenticated;

-- STEPUP-1: the write costs the permission the table's RLS already demands, plus the role's MFA.
select set_config('request.jwt.claims', '{"sub":"18300000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
select throws_ok($$insert into public.campaign_daily_metrics (tenant_id, marketing_campaign_id, metric_date, spend_amount, currency_code, impressions, clicks, revenue_amount)
                   values ('18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000cc', date '2026-08-02', 1, 'EGP', 1, 1, 999999)$$,
                 '42501', 'multi-factor authentication required for this role', 'campaign_daily_metrics: insert at aal1 needs step-up');
select throws_ok($$update public.campaign_daily_metrics set spend_amount = 0, revenue_amount = 5000000
                   where id = '18300000-0000-0000-0000-0000000000dd'$$,
                 '42501', 'multi-factor authentication required for this role', 'campaign_daily_metrics: update at aal1 needs step-up');
select set_config('request.jwt.claims', '{"sub":"18300000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
select lives_ok($$insert into public.campaign_daily_metrics (tenant_id, marketing_campaign_id, metric_date, spend_amount, currency_code, impressions, clicks, revenue_amount)
                  values ('18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000cc', date '2026-08-03', 1, 'EGP', 1, 1, 2)$$,
                'campaign_daily_metrics: insert at aal2 succeeds');
select lives_ok($$update public.campaign_daily_metrics set clicks = 6 where id = '18300000-0000-0000-0000-0000000000dd'$$,
                'campaign_daily_metrics: update at aal2 succeeds');
select set_config('request.jwt.claims', '{"sub":"18300000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
select throws_ok($$insert into public.campaign_daily_metrics (tenant_id, marketing_campaign_id, metric_date, spend_amount, currency_code, impressions, clicks, revenue_amount)
                   values ('18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000cc', date '2026-08-04', 1, 'EGP', 1, 1, 2)$$,
                 '42501', null, 'campaign_daily_metrics: a non-holder is refused');

select set_config('request.jwt.claims', '{"sub":"18300000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
select throws_ok($$insert into public.exchange_rate_adjustments (tenant_id, booking_item_id, original_exchange_rate_id, new_exchange_rate_id, reason_code, reason_text)
                   values ('18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000f1', '18300000-0000-0000-0000-0000000000ea',
                           '18300000-0000-0000-0000-0000000000eb', 'incorrect_rate', 'aal1 pin')$$,
                 '42501', 'multi-factor authentication required for this role', 'exchange_rate_adjustments: insert at aal1 needs step-up');
select set_config('request.jwt.claims', '{"sub":"18300000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
select lives_ok($$insert into public.exchange_rate_adjustments (tenant_id, booking_item_id, original_exchange_rate_id, new_exchange_rate_id, reason_code, reason_text)
                  values ('18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000f1', '18300000-0000-0000-0000-0000000000ea',
                          '18300000-0000-0000-0000-0000000000eb', 'incorrect_rate', 'stepped up')$$,
                'exchange_rate_adjustments: insert at aal2 succeeds');

-- ENTRY-1: a signed-in caller creates a booking item only at 'draft' with no lifecycle stamp.
select set_config('request.jwt.claims', '{"sub":"18300000-0000-0000-0000-0000000000a3","aal":"aal1"}', true);
select throws_ok(format($f$insert into public.booking_items (tenant_id, booking_id, service_type_code, currency_code, owner_user_id, %s)
                          values ('18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000b2', 'flight_ticket', 'USD',
                                  '18300000-0000-0000-0000-000000000013', %s)$f$, cols, vals),
                 '23514', 'a booking item is created at ''draft'' with no lifecycle stamp (canon 26); use app.advance_booking_item to move it',
                 'booking_items: ' || label || ' is refused') from item_entry_cases order by label;
select lives_ok($$select app.create_booking_item('18300000-0000-0000-0000-0000000000b2', 'flight_ticket', 'USD', 0, 0, null, null, false)$$,
                'booking_items: the RPC door still creates the draft item');
reset role;

select set_config('request.jwt.claims', '', true);
select lives_ok($$insert into public.booking_items (tenant_id, booking_id, service_type_code, currency_code, base_status_code)
                  values ('18300000-0000-0000-0000-000000000001', '18300000-0000-0000-0000-0000000000b1', 'flight_ticket', 'USD', 'in_progress')$$,
                'booking_items: session-less platform paths stay exempt');

select results_eq(
    $$select c.relname::text collate "default", t.tgname::text collate "default", (t.tgtype & 4) <> 0, (t.tgtype & 16) <> 0
      from pg_trigger t join pg_class c on c.oid = t.tgrelid
      where not t.tgisinternal
        and t.tgname in ('leads_enforce_archive_authority', 'quotations_enforce_archive_authority',
                         'booking_items_enforce_archive_authority', 'invoices_enforce_archive_authority',
                         'campaign_daily_metrics_guard_write_capability',
                         'exchange_rate_adjustments_guard_write_capability', 'booking_items_guard_entry_state')
      order by 1, 2$$,
    $$values ('booking_items', 'booking_items_enforce_archive_authority', true, true),
             ('booking_items', 'booking_items_guard_entry_state', true, false),
             ('campaign_daily_metrics', 'campaign_daily_metrics_guard_write_capability', true, true),
             ('exchange_rate_adjustments', 'exchange_rate_adjustments_guard_write_capability', true, true),
             ('invoices', 'invoices_enforce_archive_authority', true, true),
             ('leads', 'leads_enforce_archive_authority', true, true),
             ('quotations', 'quotations_enforce_archive_authority', true, true)$$,
    'each door is attached at INSERT, and the archive and step-up doors also at UPDATE');

select * from finish();
rollback;
