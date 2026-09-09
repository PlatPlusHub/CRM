"""Slice 11 concurrency proof: two customer exposure writes share one threshold crossing."""
import subprocess
import threading

PSQL = ["docker", "exec", "-i", "supabase_db_ORVION", "psql", "-X", "-U", "postgres", "-d", "postgres", "-q", "-t", "-A", "-v", "ON_ERROR_STOP=1", "-f", "-"]
TENANT = "c1100000-0000-0000-0000-000000000001"
CUSTOMER = "c1100000-0000-0000-0000-0000000000d1"
OWNER = "71000000-0000-0000-0000-0000000000a1"

def psql(sql: str) -> str:
    r = subprocess.run(PSQL, input=sql, text=True, capture_output=True)
    if r.returncode:
        raise RuntimeError(r.stderr)
    return r.stdout.strip()

psql(f"""
begin;
insert into auth.users(id,email,email_confirmed_at) values ('{OWNER}','c11@example.test',now());
insert into public.tenants(id,name,slug,status) values ('{TENANT}','Concurrency','slice11-concurrency','active');
insert into public.subscriptions(tenant_id,subscription_plan_id,subscription_status_code)
select '{TENANT}',id,'active' from public.subscription_plans where plan_code='enterprise';
insert into public.users(id,tenant_id,full_name,email,is_active,auth_user_id)
values ('c1100000-0000-0000-0000-000000000011','{TENANT}','Owner','c11@example.test',true,'{OWNER}');
insert into public.user_role_assignments(tenant_id,user_id,role_id,scope_type)
select '{TENANT}','c1100000-0000-0000-0000-000000000011',id,'tenant' from public.roles where code='owner';
insert into public.customers(id,tenant_id,customer_type_code,full_name,credit_limit_amount,credit_limit_currency_code)
values ('{CUSTOMER}','{TENANT}','person','Concurrent Customer',1000,'EGP');
commit;
""")

def writer(suffix: str) -> None:
    psql(f"""
begin;
set local role authenticated;
select set_config('request.jwt.claims','{{"sub":"{OWNER}","aal":"aal2"}}',true);
insert into public.invoices(tenant_id,customer_id,invoice_number,invoice_date,currency_code,total_amount,status_code)
values ('{TENANT}','{CUSTOMER}','INV-C11-{suffix}',current_date,'EGP',600,'draft');
update public.invoices set status_code='issued' where tenant_id='{TENANT}' and invoice_number='INV-C11-{suffix}';
select pg_sleep(1);
commit;
""")

a = threading.Thread(target=writer, args=("A",))
b = threading.Thread(target=writer, args=("B",))
a.start(); b.start(); a.join(); b.join()

exposure, events = psql(f"""
select (select exposure from app.customer_exposure_in_limit_currency('{TENANT}','{CUSTOMER}','EGP'));
select count(*) from public.events where tenant_id='{TENANT}' and entity_id='{CUSTOMER}' and event_type_code='customer_credit_threshold_exceeded';
""").splitlines()
assert exposure == "1200.0000", exposure
assert events == "1", events
print("CUSTOMER CONCURRENCY: PASS (two overlapping writes, one warning crossing)")
