-- pgTAP: Batch 6 exit -- a ledger entry balances in one currency, and a payment carries value.
--
-- ATTACK-CLASSES: DOOR BUSINESS INPUT STATE AUTH=N/A PRIVILEGE=N/A TENANT=N/A OBSERVABILITY=N/A REPLAY=N/A CONCURRENCY=N/A
--   AUTH/PRIVILEGE/TENANT=N/A -- who may post or pay is unchanged and pinned by `56_...`, `140_...` and `145_...`;
--     this file asks what an entry and a payment must BE, on every door, the platform's included.
--   OBSERVABILITY=N/A -- no event changes; a refused write records nothing because it does not exist.
--   REPLAY/CONCURRENCY=N/A -- both rules judge one entry or one row; the balance trigger's two-session
--     proof is JE-4's (`145_...`).
--
-- JE-2: `app.create_journal_entry` accepted a 100 USD debit against a 100 EGP credit -- two amounts in
--   different units summed as if one. No standard and no ERP balances an entry that way (IAS 21.21
--   records a foreign transaction in the functional currency at the spot rate). Until DC-11 decides
--   the translation model, an entry balances in ONE currency. The refusal lives in the deferred
--   balance trigger, so it binds the RPC and the platform's direct writes alike.
-- PAY-4: a zero-value payment coded `customer_refund` was accepted at the table door. Both sanctioned
--   writers refuse `amount <= 0` and a refund is a `refunds` row, so a payment row carries value.
--
-- ON `set constraints all immediate` BELOW: the balance triggers fire at COMMIT, which pgTAP never
-- reaches; each ledger case forces the check inside its own DO block (the `70_...` pattern).
create extension if not exists pgtap with schema extensions;

begin;
select plan(11);

insert into auth.users (id, email) values
  ('18500000-0000-0000-0000-0000000000a1','own@j185.test');
insert into public.tenants (id, name, slug, status) values
  ('18500000-0000-0000-0000-000000000001','J185 Travel','j185-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '18500000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('18500000-0000-0000-0000-00000000000a','18500000-0000-0000-0000-000000000001','HQ','j185-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('18500000-0000-0000-0000-0000000000c1','18500000-0000-0000-0000-000000000001','18500000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('18500000-0000-0000-0000-000000000011','18500000-0000-0000-0000-000000000001','Owner','own@j185.test',true,'18500000-0000-0000-0000-0000000000a1');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('18500000-0000-0000-0000-000000000001','18500000-0000-0000-0000-000000000011','18500000-0000-0000-0000-00000000000a','18500000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '18500000-0000-0000-0000-000000000001','18500000-0000-0000-0000-000000000011', r.id, 'tenant' from public.roles r where r.code = 'owner';
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('18500000-0000-0000-0000-0000000000d1','18500000-0000-0000-0000-000000000001','person','Buyer');
-- One issued invoice, session-less fixture (the `111_...` pattern), for the sanctioned RPC.
insert into public.invoices (id, tenant_id, customer_id, invoice_number, invoice_date, currency_code, total_amount, status_code) values
  ('18500000-0000-0000-0000-0000000000e1','18500000-0000-0000-0000-000000000001','18500000-0000-0000-0000-0000000000d1','J185-INV-1',current_date,'EGP',5000,'issued');

select set_config('request.jwt.claims','{"sub":"18500000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select app.seed_default_chart_of_accounts();
reset role;

-- =============================================================================================
-- 1-5. JE-2: an entry balances in one currency, on every door.
-- =============================================================================================
set local role authenticated;
select throws_ok($q$do $x$ begin
    perform app.create_journal_entry('manual_entry', current_date, 'JE-2',
      '[{"account_code":"1000","debit":100,"currency":"USD"},{"account_code":"4000","credit":100,"currency":"EGP"}]'::jsonb);
    execute 'set constraints all immediate';
  end $x$$q$,
  '23514', null,
  'JE-2: the RPC no longer balances a 100 USD debit against a 100 EGP credit');

select throws_like($q$do $x$ begin
    perform app.create_journal_entry('manual_entry', current_date, 'JE-2b',
      '[{"account_code":"1000","debit":100,"currency":"USD"},{"account_code":"4000","credit":60,"currency":"USD"},
        {"account_code":"4100","credit":40,"currency":"EGP"}]'::jsonb);
    execute 'set constraints all immediate';
  end $x$$q$,
  '%mixes currencies (EGP, USD)%(JE-2)',
  'JE-2: an entry that would balance as numbers across USD and EGP lines is refused, and the refusal names both currencies');

select lives_ok($q$do $x$ begin
    perform app.create_journal_entry('manual_entry', current_date, 'USD-1',
      '[{"account_code":"1000","debit":100,"currency":"USD"},{"account_code":"4000","credit":100,"currency":"USD"}]'::jsonb);
    execute 'set constraints all immediate';
  end $x$$q$,
  'POSITIVE CONTROL: a balanced entry wholly in USD still posts -- the rule is one currency per entry, not EGP only');
reset role;
-- The forced check above leaves the session in immediate mode; restore deferral so each platform
-- case below is judged with all its lines written, not on its bare entry row.
set constraints all deferred;

select throws_like($q$do $x$ begin
    insert into public.journal_entries (id, tenant_id, source_type_code, entry_date)
    values ('18500000-0000-0000-0000-0000000000f1','18500000-0000-0000-0000-000000000001','manual_entry', current_date);
    insert into public.journal_entry_lines (tenant_id, journal_entry_id, chart_account_id, debit_amount, credit_amount, currency_code)
    select '18500000-0000-0000-0000-000000000001','18500000-0000-0000-0000-0000000000f1', id,
           case code when '1000' then 100 else 0 end, case code when '4000' then 100 else 0 end,
           case code when '1000' then 'USD' else 'EGP' end
      from public.chart_of_accounts where tenant_id = '18500000-0000-0000-0000-000000000001' and code in ('1000','4000');
    execute 'set constraints all immediate';
  end $x$$q$,
  '%mixes currencies (EGP, USD)%(JE-2)',
  'JE-2: the platform''s direct writes are judged by the same trigger and refused for the currency rule -- no session-less exemption');
set constraints all deferred;

select lives_ok($q$do $x$ begin
    insert into public.journal_entries (id, tenant_id, source_type_code, entry_date)
    values ('18500000-0000-0000-0000-0000000000f2','18500000-0000-0000-0000-000000000001','manual_entry', current_date);
    insert into public.journal_entry_lines (tenant_id, journal_entry_id, chart_account_id, debit_amount, credit_amount, currency_code)
    select '18500000-0000-0000-0000-000000000001','18500000-0000-0000-0000-0000000000f2', id,
           case code when '1000' then 100 else 0 end, case code when '4000' then 100 else 0 end, 'EGP'
      from public.chart_of_accounts where tenant_id = '18500000-0000-0000-0000-000000000001' and code in ('1000','4000');
    execute 'set constraints all immediate';
  end $x$$q$,
  'POSITIVE CONTROL: the same platform write in one currency passes, so the refusal above is the currency rule');

-- =============================================================================================
-- 6-11. PAY-4: a payment row carries value, on every door.
-- =============================================================================================
select is((select pg_get_constraintdef(c.oid) || ' ' || c.convalidated::text from pg_constraint c
            where c.conrelid = 'public.payments'::regclass and c.conname = 'payments_amount_positive_check'),
  'CHECK ((amount > (0)::numeric)) true',
  'STRUCTURE: payments carries a validated amount > 0 CHECK -- one control for every writer');

select set_config('request.jwt.claims','{"sub":"18500000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select throws_ok($q$insert into public.payments (tenant_id, payment_direction_code, customer_id, payment_method_code, currency_code, amount, paid_at)
                   values ('18500000-0000-0000-0000-000000000001','customer_refund','18500000-0000-0000-0000-0000000000d1','cash','EGP',0,now())$q$,
  '23514', 'new row for relation "payments" violates check constraint "payments_amount_positive_check"',
  'PAY-4: the owner at aal2 cannot record a zero-value payment coded customer_refund at the table door');

select lives_ok($q$select app.record_payment('18500000-0000-0000-0000-0000000000e1', 5000, 'cash', now(), 'J185-PAY')$q$,
  'POSITIVE CONTROL: the sanctioned RPC still records a positive payment');
reset role;

select throws_ok($q$insert into public.payments (tenant_id, payment_direction_code, customer_id, payment_method_code, currency_code, amount, paid_at)
                   values ('18500000-0000-0000-0000-000000000001','customer_payment','18500000-0000-0000-0000-0000000000d1','cash','EGP',0,now())$q$,
  '23514', 'new row for relation "payments" violates check constraint "payments_amount_positive_check"',
  'PAY-4: the platform cannot write a zero-value payment either');

select lives_ok($q$insert into public.payments (tenant_id, payment_direction_code, customer_id, payment_method_code, currency_code, amount, paid_at)
                   values ('18500000-0000-0000-0000-000000000001','customer_payment','18500000-0000-0000-0000-0000000000d1','cash','EGP',0.0001,now())$q$,
  'BOUNDARY: the smallest positive amount the column holds is a payment');

select throws_ok($q$update public.payments set amount = 0 where reference_number = 'J185-PAY'$q$,
  '23514', 'new row for relation "payments" violates check constraint "payments_amount_positive_check"',
  'PAY-4: a recorded payment cannot be emptied to zero afterwards');

select * from finish();
rollback;
