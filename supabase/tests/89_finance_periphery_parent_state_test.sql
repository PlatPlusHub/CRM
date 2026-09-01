-- pgTAP: PAY-1 / JE-1 / DEV-1 (`202607059500`) -- the Batch-6 slice of tables `authenticated` can
-- write that no test had ever been ABOUT.
--
-- THE ARRANGEMENT IS THE POINT, and it is the standing lesson from PARENT-1. Every state-dependent
-- pair below asks the RPC and the table door THE SAME QUESTION AGAINST THE SAME STATE, with no
-- transition in between. PARENT-1's defect survived a green HTTP suite precisely because that suite
-- refused the RPC while the parent was closed and then wrote to the table after reopening it: two
-- correct assertions, arranged so neither could catch anything.
--
-- The last assertion is the CLASS, and its scope is stated honestly rather than generously:
-- it covers state carried in a CATALOG-CODED column (derived from `app.status_transitions` UNION the
-- columns `app.enforce_catalog_codes` triggers validate, read out of the trigger arguments), with
-- the parent defined STRUCTURALLY by a foreign key and the child restricted to tables
-- `authenticated` may INSERT. It does NOT cover state carried as a boolean flag -- JE-1 is exactly
-- that residual, and it was found by reading, not by the detector. Saying so is the point: a guard
-- whose description outruns its measurement is the PAR-3 finding.
create extension if not exists pgtap with schema extensions;

begin;
select plan(21);

insert into auth.users (id, email) values ('89000000-0000-0000-0000-0000000000a1','fin@f89.example');
insert into public.tenants (id, name, slug, status) values ('89000000-0000-0000-0000-000000000001','F89 Travel','f89-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '89000000-0000-0000-0000-000000000001', sp.id,'active' from public.subscription_plans sp where sp.plan_code='enterprise';
insert into public.branches (id, tenant_id, name, slug) values ('89000000-0000-0000-0000-00000000000a','89000000-0000-0000-0000-000000000001','Main','f89-main');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name)
values ('89000000-0000-0000-0000-0000000000c1','89000000-0000-0000-0000-000000000001','89000000-0000-0000-0000-00000000000a','finance','Finance');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id)
values ('89000000-0000-0000-0000-000000000011','89000000-0000-0000-0000-000000000001','Finance Mgr','fin@f89.example',true,'89000000-0000-0000-0000-0000000000a1');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '89000000-0000-0000-0000-000000000001','89000000-0000-0000-0000-000000000011', r.id,'tenant'
from public.roles r where r.code='finance_manager';
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
values ('89000000-0000-0000-0000-000000000001','89000000-0000-0000-0000-000000000011','89000000-0000-0000-0000-00000000000a','89000000-0000-0000-0000-0000000000c1', true);
insert into public.customers (id, tenant_id, customer_type_code, full_name, first_registered_branch_id)
values ('89000000-0000-0000-0000-0000000000cc','89000000-0000-0000-0000-000000000001','person','F89 Customer','89000000-0000-0000-0000-00000000000a');
-- Three real invoices, one in each state the rule distinguishes.
insert into public.invoices (id, tenant_id, customer_id, invoice_number, invoice_date, currency_code, total_amount, status_code)
values ('89000000-0000-0000-0000-0000000000f1','89000000-0000-0000-0000-000000000001','89000000-0000-0000-0000-0000000000cc','F89-INV-1', current_date,'EGP', 5000,'draft'),
       ('89000000-0000-0000-0000-0000000000f2','89000000-0000-0000-0000-000000000001','89000000-0000-0000-0000-0000000000cc','F89-INV-2', current_date,'EGP', 5000,'voided'),
       ('89000000-0000-0000-0000-0000000000f3','89000000-0000-0000-0000-000000000001','89000000-0000-0000-0000-0000000000cc','F89-INV-3', current_date,'EGP', 5000,'issued');
insert into public.payments (id, tenant_id, payment_direction_code, customer_id, payment_method_code, currency_code, amount, paid_at)
values ('89000000-0000-0000-0000-0000000000d1','89000000-0000-0000-0000-000000000001','customer_payment','89000000-0000-0000-0000-0000000000cc','cash','EGP',1000, now());

select set_config('request.jwt.claims','{"sub":"89000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;

-- 1
select ok(app.has_permission('RECORD_PAYMENT') and app.has_permission('CREATE_JOURNAL_ENTRY'),
  'POSITIVE CONTROL: the caller genuinely holds RECORD_PAYMENT and CREATE_JOURNAL_ENTRY, so every refusal below is the parent-state rule and not a permission');

-- ================================================================================================
-- PAY-1 -- money allocated against an invoice that was never issued, or that was voided.
-- ================================================================================================
-- 2
select is(
  (select i.status_code from public.invoices i
    where i.id = '89000000-0000-0000-0000-0000000000f1' and i.tenant_id = '89000000-0000-0000-0000-000000000001')::text,
  'draft',
  'POSITIVE CONTROL: the DRAFT invoice is visible to this caller and really is draft -- the refusals below cannot be an invisible row');

-- 3
select throws_ok(
  $$select app.record_payment('89000000-0000-0000-0000-0000000000f1', 1000, 'cash')$$,
  'P0001', 'only an issued/partially_paid/overdue invoice can be paid (is draft)',
  'POSITIVE CONTROL: the RPC refuses a payment against a DRAFT invoice');

-- 4 -- SAME STATE, no transition between this and the assertion above.
select throws_ok(
  $$insert into public.payment_allocations (tenant_id, payment_id, invoice_id, allocated_amount, currency_code)
    values ('89000000-0000-0000-0000-000000000001','89000000-0000-0000-0000-0000000000d1','89000000-0000-0000-0000-0000000000f1',1000,'EGP')$$,
  '23514', 'only an issued/partially_paid/overdue invoice can be paid (is draft)',
  'PAY-1: the TABLE now refuses it too, with the RPC''s own words -- before 202607059500 this returned INSERT 0 1 and every balance derived from allocations misstated what the customer owed');

-- 5
select throws_ok(
  $$select app.record_payment('89000000-0000-0000-0000-0000000000f2', 1000, 'cash')$$,
  'P0001', 'only an issued/partially_paid/overdue invoice can be paid (is voided)',
  'POSITIVE CONTROL: and the RPC refuses a VOIDED invoice');

-- 6
select throws_ok(
  $$insert into public.payment_allocations (tenant_id, payment_id, invoice_id, allocated_amount, currency_code)
    values ('89000000-0000-0000-0000-000000000001','89000000-0000-0000-0000-0000000000d1','89000000-0000-0000-0000-0000000000f2',1000,'EGP')$$,
  '23514', 'only an issued/partially_paid/overdue invoice can be paid (is voided)',
  'PAY-1: so does the TABLE -- 1,000 EGP had been sitting allocated against a voided invoice');

-- 7
select lives_ok(
  $$select app.record_payment('89000000-0000-0000-0000-0000000000f3', 1000, 'cash')$$,
  'NEGATIVE CONTROL: the RPC still records a payment against an ISSUED invoice -- the guard did not close the working path');

-- 8
select lives_ok(
  $$insert into public.payment_allocations (tenant_id, payment_id, invoice_id, allocated_amount, currency_code)
    values ('89000000-0000-0000-0000-000000000001','89000000-0000-0000-0000-0000000000d1','89000000-0000-0000-0000-0000000000f3',1000,'EGP')$$,
  'NEGATIVE CONTROL: and a DIRECT allocation against that same invoice works -- it is now partially_paid, which the rule admits');

-- 9 -- the archived branch takes the RPC's OTHER message, which is why it is asserted separately.
select throws_ok(
  $$with a as (
      update public.invoices set is_archived = true, archived_at = now(), archive_reason = 'test'
      where id = '89000000-0000-0000-0000-0000000000f3' and tenant_id = '89000000-0000-0000-0000-000000000001'
      returning id)
    insert into public.payment_allocations (tenant_id, payment_id, invoice_id, allocated_amount, currency_code)
    select '89000000-0000-0000-0000-000000000001','89000000-0000-0000-0000-0000000000d1', a.id, 500,'EGP' from a$$,
  '23514', 'invoice is archived or voided',
  'PAY-1: an ARCHIVED invoice is refused with the RPC''s other message -- both refusals are carried, because a caller is entitled to the same distinction on either door');

-- ================================================================================================
-- JE-1 -- a journal line posted to a RETIRED chart account.
-- ================================================================================================
select app.seed_default_chart_of_accounts();
insert into public.journal_entries (id, tenant_id, source_type_code, entry_date, description)
values ('89000000-0000-0000-0000-0000000000e1','89000000-0000-0000-0000-000000000001','manual_entry', current_date,'F89 entry');

-- 10
select is(
  (select ca.is_active from public.chart_of_accounts ca
    where ca.tenant_id = '89000000-0000-0000-0000-000000000001' and ca.code = '1000'),
  true,
  'POSITIVE CONTROL: chart account 1000 exists and is ACTIVE before anything is asserted about it');

-- 11
select lives_ok(
  $$insert into public.journal_entry_lines (tenant_id, journal_entry_id, chart_account_id, debit_amount, credit_amount, currency_code)
    select '89000000-0000-0000-0000-000000000001','89000000-0000-0000-0000-0000000000e1', ca.id, 100, 0,'EGP'
    from public.chart_of_accounts ca
    where ca.tenant_id = '89000000-0000-0000-0000-000000000001' and ca.code = '1000'$$,
  'NEGATIVE CONTROL: a direct line against an ACTIVE account posts normally');

-- 12
select lives_ok(
  $$update public.chart_of_accounts set is_active = false
    where tenant_id = '89000000-0000-0000-0000-000000000001' and code = '1000'$$,
  'the account is retired -- which the policy permits with CREATE_JOURNAL_ENTRY, and is a normal thing for an agency to do');

-- 13
select throws_ok(
  $$select app.create_journal_entry('manual_entry', current_date, 'posting to a retired account',
      jsonb_build_array(
        jsonb_build_object('account_code','1000','debit',100,'credit',0,'currency','EGP'),
        jsonb_build_object('account_code','1100','debit',0,'credit',100,'currency','EGP')))$$,
  'P0001', 'unknown or inactive chart account code: 1000',
  'POSITIVE CONTROL: the RPC refuses a line on a RETIRED account');

-- 14 -- SAME STATE.
select throws_ok(
  $$insert into public.journal_entry_lines (tenant_id, journal_entry_id, chart_account_id, debit_amount, credit_amount, currency_code)
    select '89000000-0000-0000-0000-000000000001','89000000-0000-0000-0000-0000000000e1', ca.id, 0, 100,'EGP'
    from public.chart_of_accounts ca
    where ca.tenant_id = '89000000-0000-0000-0000-000000000001' and ca.code = '1000'$$,
  '23514', 'unknown or inactive chart account code: 1000',
  'JE-1: and so does the TABLE. The RPC''s other two line rules were ALREADY here and are not re-added: the debit-xor-credit CHECK and the deferred balance trigger. Only the active-account rule was missing');

-- ================================================================================================
-- DEV-1 -- two rows for one device, and revoking one left the other trusted.
-- ================================================================================================
-- 15
select lives_ok(
  $$select app.record_trusted_device('F89-LAPTOP')$$,
  'POSITIVE CONTROL: the device is recorded');

-- The SECOND call is what assertion 16 is actually about; without it the count below would be 1
-- because the device was recorded once, and the assertion would pass while proving nothing.
select app.record_trusted_device('F89-LAPTOP');

-- 16
select is(
  (select count(*)::int from public.trusted_devices
    where auth_user_id = '89000000-0000-0000-0000-0000000000a1' and device_identifier = 'F89-LAPTOP'),
  1,
  'DEV-1: calling it AGAIN re-trusts the same row instead of adding a second -- the upsert is now one statement, so the window two concurrent callers drove through is gone');

-- 17
select throws_ok(
  $$insert into public.trusted_devices (auth_user_id, device_identifier, status_code, verified_at)
    values ('89000000-0000-0000-0000-0000000000a1','F89-LAPTOP','trusted', now())$$,
  '23505', null,
  'DEV-1: and the direct door cannot create the duplicate either -- the index states the invariant app.record_trusted_device always assumed');

select app.revoke_trusted_device(
  (select d.id from public.trusted_devices d
    where d.auth_user_id = '89000000-0000-0000-0000-0000000000a1' and d.device_identifier = 'F89-LAPTOP'));

-- 18
select is(
  (select d.status_code || '/' || (d.revoked_at is not null)::text
   from public.my_trusted_devices() d where d.device_identifier = 'F89-LAPTOP'),
  'revoked/true',
  'DEV-1: after a revoke the user''s own device list shows exactly ONE row and it is revoked -- previously it showed the same device as revoked AND trusted at once');

-- ================================================================================================
-- Mutation (PAR-4), third-from-last so its count survives the rollback (TEST-3).
-- ================================================================================================
reset role;
savepoint m1;
drop trigger payment_allocations_guard_parent_state on public.payment_allocations;
-- 19
select lives_ok(
  $$insert into public.payment_allocations (tenant_id, payment_id, invoice_id, allocated_amount, currency_code)
    values ('89000000-0000-0000-0000-000000000001','89000000-0000-0000-0000-0000000000d1','89000000-0000-0000-0000-0000000000f1',1000,'EGP')$$,
  'MUTATION: with the guard dropped the allocation lands on the DRAFT invoice again -- proving that trigger, and not RLS or FIN-10''s ceiling, is the enforcer');
rollback to savepoint m1;

-- 20
select throws_ok(
  $$insert into public.payment_allocations (tenant_id, payment_id, invoice_id, allocated_amount, currency_code)
    values ('89000000-0000-0000-0000-000000000001','89000000-0000-0000-0000-0000000000d1','89000000-0000-0000-0000-0000000000f1',1000,'EGP')$$,
  '23514', 'only an issued/partially_paid/overdue invoice can be paid (is draft)',
  '...and once the mutation is rolled back the guard is BACK: the identical allocation against the identical draft invoice is refused again');

-- ================================================================================================
-- THE CLASS, re-derived from the catalog on every run. Nine pairs remain and each is CLASSIFIED,
-- which is what makes this an inventory rather than an exemption list:
--   SAME-TRANSACTION CREATION (7) -- the function creates the parent in the same transaction, so
--     there is no prior state to refuse on: create_customer -> customer_identity_signals,
--     create_journal_entry -> journal_entry_lines (the ENTRY; the ACCOUNT rule is JE-1 above),
--     record_payment -> payment_allocations (the PAYMENT; the INVOICE rule is PAY-1 above),
--     upload_document -> documents, and upload_subscription_payment_proof's three, which build
--     document + version + proof + link in one transaction.
--   READS BUT REFUSES NOTHING (2) -- record_lead_interaction reads `lead_status_code` only to decide
--     the assigned -> contacted transition; record_refund refuses on tenancy alone.
-- Counterexample-tested BOTH ways before being trusted: dropping this migration's two triggers takes
-- the count 9 -> 10 and the reappearing pair is `record_payment -> payment_allocations (invoices)`,
-- PAY-1 itself; rolling the drop back returns it to 9.
-- ================================================================================================
-- 21
select is(
  (with state_cols as (
     select distinct table_name, status_column as col from app.status_transitions
     union
     select c.relname, (regexp_matches(pg_get_triggerdef(t.oid), '''([a-z_]+)''\s*,\s*''[a-z_]+''', 'g'))[1]
     from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
     join pg_namespace n on n.oid = c.relnamespace
     join pg_proc p on p.oid = t.tgfoid
     where not t.tgisinternal and n.nspname = 'public' and p.proname = 'enforce_catalog_codes'),
   fk as (select c.relname as child, pc.relname as parent
          from pg_constraint k
          join pg_class c on c.oid = k.conrelid
          join pg_class pc on pc.oid = k.confrelid
          join pg_namespace n on n.oid = c.relnamespace
          where k.contype = 'f' and n.nspname = 'public' and pc.relnamespace = n.oid),
   writable as (select table_name from information_schema.role_table_grants
                where table_schema = 'public' and grantee = 'authenticated' and privilege_type = 'INSERT'),
   fns as (select p.proname, p.prosrc from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'app' and p.prokind = 'f' and p.prorettype <> 'trigger'::regtype),
   reads as (select f.proname, s.table_name as parent from fns f join state_cols s
             on f.prosrc ~ ('public\.' || s.table_name || '\M') and f.prosrc ~ ('\m' || s.col || '\M')),
   writes as (select f.proname, m[1] as child
              from fns f, regexp_matches(f.prosrc, 'insert\s+into\s+public\.(\w+)', 'g') m),
   pairs as (select distinct r.proname, r.parent, w.child
             from reads r join writes w on w.proname = r.proname
             where w.child <> r.parent
               and exists (select 1 from fk where fk.child = w.child and fk.parent = r.parent)
               and w.child in (select table_name from writable)),
   guarded as (select distinct c.relname as child, s.table_name as parent
               from pg_trigger t
               join pg_class c on c.oid = t.tgrelid
               join pg_namespace n on n.oid = c.relnamespace
               join pg_proc p on p.oid = t.tgfoid, state_cols s
               where not t.tgisinternal and n.nspname = 'public'
                 and (t.tgtype::int & 2) = 2 and (t.tgtype::int & 4) = 4
                 and p.prosrc ~ ('public\.' || s.table_name || '\M')
                 and p.prosrc ~ ('\m' || s.col || '\M'))
   select coalesce(string_agg(distinct pr.proname || ' -> ' || pr.child || ' (' || pr.parent || ')', ', '
                     order by pr.proname || ' -> ' || pr.child || ' (' || pr.parent || ')'), '')
   from pairs pr left join guarded g on g.child = pr.child and g.parent = pr.parent
   where g.child is null)::text,
  'create_customer -> customer_identity_signals (customers), create_journal_entry -> journal_entry_lines (journal_entries), record_lead_interaction -> lead_interactions (leads), record_payment -> payment_allocations (payments), record_refund -> refunds (payments), upload_document -> documents (document_versions), upload_subscription_payment_proof -> document_links (subscription_payment_proofs), upload_subscription_payment_proof -> documents (document_versions), upload_subscription_payment_proof -> subscription_payment_proofs (documents)',
  'CLASS GUARD (PAY-1): every app function that reads a CATALOG-CODED parent state and INSERTs into a table `authenticated` can write, where the parent is a real FK parent, either has a table-door guard or is one of these nine classified non-defects. Scope stated honestly: boolean-flag state is NOT covered -- JE-1 is that residual and was found by reading, not by this.');

select * from finish();
rollback;
