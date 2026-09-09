"""Local concurrency proofs. Fixtures remain; reset before release verification."""
import queue
import subprocess
import threading
import time
import uuid

PSQL = ["docker", "exec", "-i", "supabase_db_ORVION", "psql", "-X", "-U", "postgres",
        "-d", "postgres", "-q", "-t", "-A", "-v", "ON_ERROR_STOP=1", "-f", "-"]


def psql(sql):
    r = subprocess.run(PSQL, input=sql, text=True, capture_output=True, timeout=30)
    if r.returncode:
        raise RuntimeError(r.stderr)
    return r.stdout.strip()


class Session:
    def __init__(self, name, sql):
        self.name, self.lines = name, queue.Queue()
        self.process = subprocess.Popen(PSQL, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        stderr=subprocess.STDOUT, text=True, bufsize=1)
        def read():
            for line in self.process.stdout:
                self.lines.put(line.rstrip())
            self.lines.put(None)
        threading.Thread(target=read, daemon=True).start()
        self.send(f"set application_name='{name}'; set statement_timeout='20s';\n" + sql)

    def send(self, sql):
        self.process.stdin.write(sql + "\n")
        self.process.stdin.flush()

    def ready(self):
        self.send(r"\echo READY")
        output = []
        while True:
            line = self.lines.get(timeout=25)
            if line == 'READY':
                return output
            if line is None:
                raise RuntimeError('\n'.join(output))
            output.append(line)

    def finish(self, sql="commit;"):
        # A refused worker may exit between releasing its blocker and sending COMMIT.
        try:
            self.send(sql)
            self.process.stdin.close()
        except (BrokenPipeError, OSError):
            pass  # The exit code and exact database error are asserted by the caller below.
        self.process.wait(timeout=25)
        output = []
        while True:
            line = self.lines.get(timeout=5)
            if line is None:
                break
            output.append(line)
        return self.process.returncode, '\n'.join(output)

    def close(self):
        if self.process.poll() is None:
            psql(f"select pg_terminate_backend(pid) from pg_stat_activity where application_name='{self.name}'")
            self.process.wait(timeout=10)


def blocked_by(waiter, holder):
    return psql(f"""select exists(select 1 from pg_stat_activity w, pg_stat_activity h
        where w.application_name='{waiter.name}' and h.application_name='{holder.name}'
          and h.pid=any(pg_blocking_pids(w.pid)))""") == 't'


def wait_blocked(waiter, holder):
    deadline = time.monotonic() + 12
    while time.monotonic() < deadline:
        if blocked_by(waiter, holder):
            print(f"OVERLAP PROVEN: {waiter.name} blocked by {holder.name}", flush=True)
            return
        if waiter.process.poll() is not None:
            raise AssertionError('Worker exited before required overlap')
        time.sleep(.05)
    raise AssertionError('No database blocking edge observed; overlap is UNPROVEN')


def main():
    tenant, owner, actor, customer, source, target = [str(uuid.uuid4()) for _ in range(6)]
    prefix = 'c11_' + uuid.uuid4().hex[:10]
    sessions = []
    psql(f"""
    insert into auth.users(id,email,email_confirmed_at) values('{owner}','{prefix}@example.test',now());
    insert into public.tenants(id,name,slug,status) values('{tenant}','Concurrency','{prefix}','active');
    insert into public.subscriptions(tenant_id,subscription_plan_id,subscription_status_code)
      select '{tenant}',id,'active' from public.subscription_plans where plan_code='enterprise';
    insert into public.users(id,tenant_id,full_name,email,is_active,auth_user_id)
      values('{actor}','{tenant}','Owner','{prefix}@example.test',true,'{owner}');
    insert into public.user_role_assignments(tenant_id,user_id,role_id,scope_type)
      select '{tenant}','{actor}',id,'tenant' from public.roles where code='owner';
    insert into public.customers(id,tenant_id,customer_type_code,full_name,credit_limit_amount,credit_limit_currency_code)
      values('{customer}','{tenant}','person','Capped',1000,'EGP');
    insert into public.customers(id,tenant_id,customer_type_code,full_name)
      values('{source}','{tenant}','person','Source'),('{target}','{tenant}','person','Target');
    """)
    auth = f"""set local role authenticated;
    select set_config('request.jwt.claims','{{"sub":"{owner}","aal":"aal2"}}',true);"""

    def session(suffix, sql):
        s = Session(prefix + suffix, sql)
        sessions.append(s)
        return s

    def invoice(suffix):
        return f"""begin; {auth}
        insert into public.invoices(tenant_id,customer_id,invoice_number,invoice_date,currency_code,total_amount,status_code)
          values('{tenant}','{customer}','{prefix}{suffix}',current_date,'EGP',600,'draft');
        update public.invoices set status_code='issued' where tenant_id='{tenant}' and invoice_number='{prefix}{suffix}';"""

    try:
        a = session('_credit_a', invoice('A'))
        a.ready()  # Write complete, deliberately uncommitted until B is seen waiting.
        b = session('_credit_b', invoice('B'))
        wait_blocked(b, a)
        assert a.finish()[0] == 0
        b.ready()
        assert not blocked_by(b, a), 'Detector credited a finished transaction'
        assert b.finish()[0] == 0
        result = psql(f"""select exposure from app.customer_exposure_in_limit_currency('{tenant}','{customer}','EGP');
        select count(*) from public.events where tenant_id='{tenant}' and entity_id='{customer}'
          and event_type_code='customer_credit_threshold_exceeded';""").splitlines()
        assert result == ['1200.0000', '1'], result
        print('CUSTOMER CREDIT CONCURRENCY: PASS (observed overlap, 1200 exposure, one warning)', flush=True)

        # Intentional replay refusal, not a later collision with archive metadata or an FK.
        merge = f"begin; {auth} select app.merge_customer_identity('{source}','{target}','race');"
        a = session('_merge_a', merge)
        a.ready()
        b = session('_merge_b', merge)
        wait_blocked(b, a)
        assert a.finish()[0] == 0
        code, output = b.finish()
        assert code != 0 and 'source customer is already archived (merged?)' in output, output
        result = psql(f"""select count(*) from public.customer_identity_merges where source_customer_id='{source}';
        select count(*) from public.events where tenant_id='{tenant}' and event_type_code='customer_identity_merged';""").splitlines()
        assert result == ['1', '1'], result
        print('CUSTOMER MERGE CONCURRENCY: PASS (observed overlap, intentional replay refusal, one audit/event)', flush=True)

        # The actual corruption case: reciprocal merges previously committed two archived customers.
        source, target = str(uuid.uuid4()), str(uuid.uuid4())
        psql(f"""insert into public.customers(id,tenant_id,customer_type_code,full_name)
          values('{source}','{tenant}','person','Reverse source'),('{target}','{tenant}','person','Reverse target');""")
        a = session('_reverse_a', f"begin; {auth} select app.merge_customer_identity('{source}','{target}','forward');")
        a.ready()
        b = session('_reverse_b', f"begin; {auth} select app.merge_customer_identity('{target}','{source}','reverse');")
        wait_blocked(b, a)
        assert a.finish()[0] == 0
        code, output = b.finish()
        assert code != 0 and 'target customer is already archived' in output, output
        result = psql(f"""select count(*) from public.customers where id in ('{source}','{target}') and is_archived;
        select count(*) from public.customer_identity_merges where source_customer_id in ('{source}','{target}');""").splitlines()
        assert result == ['1', '1'], result
        print('REVERSE MERGE CONCURRENCY: PASS (one archived source, active survivor, one merge)', flush=True)
    finally:
        for s in sessions:
            s.close()


if __name__ == '__main__':
    main()
