"""Two-session proofs that a subscription transition is judged on the row it replaces (SUB-4, SUB-5).

Every case holds one writer's transaction open, proves through pg_blocking_pids that the second
writer is WAITING on it (never by timing), releases the first, and then asserts the final state and
the recorded events. Each case uses its own tenant and runs even when an earlier one failed, so a
run names every failing case; the exit code is non-zero if any failed. Fixtures remain; reset before
release verification. Reuses the session harness of verify_customer_concurrency.py.
"""
import os
import subprocess
import sys
import uuid

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from verify_customer_concurrency import Session, psql, wait_blocked  # noqa: E402

PREFIX = 's4_' + uuid.uuid4().hex[:10]
SESSIONS = []


def release(s):
    # Session.close terminates the backend, but psql keeps waiting on its open stdin; close that too.
    if s.process.poll() is None:
        psql(f"select pg_terminate_backend(pid) from pg_stat_activity where application_name='{s.name}'")
        try:
            s.process.stdin.close()
        except OSError:
            pass
        try:
            s.process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            s.process.kill()
            s.process.wait(timeout=10)


def session(suffix, sql):
    s = Session(PREFIX + suffix, sql)
    SESSIONS.append(s)
    return s


def tenant(state, plan='starter', due_grace=False):
    t, owner, actor = (str(uuid.uuid4()) for _ in range(3))
    slug = PREFIX + t[:6]
    psql(f"""
    insert into auth.users(id,email,email_confirmed_at) values('{owner}','{slug}@example.test',now());
    insert into public.tenants(id,name,slug,status) values('{t}','Subscription race','{slug}','active');
    insert into public.subscriptions(tenant_id,subscription_plan_id,subscription_status_code,starts_at,ends_at,grace_ends_at)
      select '{t}',id,'{state}',now()-interval '40 days',
             {"now()-interval '5 days'" if due_grace else 'null'},
             {"now()-interval '1 day'" if due_grace else 'null'}
      from public.subscription_plans where plan_code='{plan}';
    insert into public.users(id,tenant_id,full_name,email,is_active,auth_user_id)
      values('{actor}','{t}','Owner','{slug}@example.test',true,'{owner}');
    insert into public.user_role_assignments(tenant_id,user_id,role_id,scope_type)
      select '{t}','{actor}',id,'tenant' from public.roles where code='owner';
    """)
    return t, owner


def issue(t):
    return psql(f"select app.platform_issue_license_token('{t}','professional','annual',false,7,'race');").splitlines()[-1]


def redeem(owner, code):
    return f"""begin; set local role authenticated;
    select set_config('request.jwt.claims','{{"sub":"{owner}","aal":"aal2"}}',true);
    select app.redeem_license_token('{code}');"""


def suspend(t):
    return f"begin; select app.platform_transition_subscription('{t}','suspended','race');"


def renew(t):
    return f"begin; select app.platform_activate_subscription('{t}','professional','annual',false);"


JOB = "begin; select app.process_subscription_lifecycle();"


def state(t):
    return psql(f"select subscription_status_code from public.subscriptions where tenant_id='{t}';")


def events(t):
    return psql(f"""select string_agg(coalesce(previous_state,'-') || '->' || new_state, ',' order by seq)
      from public.events where tenant_id='{t}' and entity_type='subscription';""")


def refused_on_active(out):
    return 'canon 26 does not allow active -> suspended' in out


def case_a():
    """SUB-4: a redemption commits read_only -> active while the suspension waits on the row.
    The suspension must be judged on ACTIVE and refused, never write suspended over it."""
    t, owner = tenant('read_only')
    a = session('_a_redeem', redeem(owner, issue(t)))
    a.ready()
    b = session('_a_suspend', suspend(t))
    wait_blocked(b, a)
    assert a.finish()[0] == 0
    rc, out = b.finish()
    assert rc != 0 and refused_on_active(out), f'suspension not refused on active: rc={rc} state={state(t)} events={events(t)} out={out!r}'
    assert (state(t), events(t)) == ('active', 'read_only->active'), (state(t), events(t))
    return 'observed overlap, judged on active, refused, one true event'


def case_b():
    """LIC-4 kept: the suspension commits first; the waiting redemption may not consume the code
    the suspension revoked, so the tenant stays suspended."""
    t, owner = tenant('read_only')
    code = issue(t)
    a = session('_b_suspend', suspend(t))
    a.ready()
    b = session('_b_redeem', redeem(owner, code))
    wait_blocked(b, a)
    assert a.finish()[0] == 0
    rc, out = b.finish()
    assert rc != 0, f'redemption of a revoked code committed: state={state(t)} events={events(t)}'
    assert (state(t), events(t)) == ('suspended', 'read_only->suspended'), (state(t), events(t))
    return 'observed overlap, revoked code not redeemed, still suspended'


def case_c():
    """SUB-5: a Platform Owner renewal commits grace_period -> active while the lifecycle job waits
    on the row. The job must re-read active and leave the renewed tenant alone."""
    t, _ = tenant('grace_period', plan='professional', due_grace=True)
    a = session('_c_renew', renew(t))
    a.ready()
    b = session('_c_job', JOB)
    wait_blocked(b, a)
    assert a.finish()[0] == 0
    assert b.finish()[0] == 0
    assert (state(t), events(t)) == ('active', 'grace_period->active'), (state(t), events(t))
    return 'observed overlap, renewed tenant left active, one true event'


def case_d():
    """Event truth: the lifecycle job commits grace_period -> read_only while a renewal waits.
    The renewal is still legal (read_only -> active) and must record read_only as its from-state."""
    t, _ = tenant('grace_period', plan='professional', due_grace=True)
    a = session('_d_job', JOB)
    a.ready()
    b = session('_d_renew', renew(t))
    wait_blocked(b, a)
    assert a.finish()[0] == 0
    assert b.finish()[0] == 0
    assert (state(t), events(t)) == ('active', 'grace_period->read_only,read_only->active'), (state(t), events(t))
    return 'observed overlap, both moves legal, every from-state true'


def case_e():
    """Lock order: a redemption holds its activation-code row and then needs the subscription row.
    A concurrent suspension must wait on the CODE row first; if it locked the subscription first,
    the two would deadlock. The holder takes the code row exactly as the redemption's claim does."""
    t, _ = tenant('read_only')
    issue(t)
    a = session('_e_claim', f"begin; select 1 from public.tenant_license_activations where tenant_id='{t}' for update;")
    a.ready()
    b = session('_e_suspend', suspend(t))
    wait_blocked(b, a)
    a.send(f"select app.platform_activate_subscription('{t}','professional','annual',false);")
    a.ready()
    assert a.finish()[0] == 0, 'the code-row holder could not reach the subscription row'
    rc, out = b.finish()
    assert 'deadlock' not in out, f'deadlock: {out!r}'
    assert rc != 0 and refused_on_active(out), f'suspension not refused on active: rc={rc} state={state(t)} events={events(t)} out={out!r}'
    assert state(t) == 'active', state(t)
    return 'suspension waited on the code row, no deadlock, judged on active'


def case_f():
    """SUB-4 without a code row: a renewal commits read_only -> active while a suspension waits.
    No activation code exists, so only the suspension's own subscription lock serializes the two;
    case A alone cannot prove that lock, because the revocation also waits on the code row."""
    t, _ = tenant('read_only')
    a = session('_f_renew', renew(t))
    a.ready()
    b = session('_f_suspend', suspend(t))
    wait_blocked(b, a)
    assert a.finish()[0] == 0
    rc, out = b.finish()
    assert rc != 0 and refused_on_active(out), f'suspension not refused on active: rc={rc} state={state(t)} events={events(t)} out={out!r}'
    assert (state(t), events(t)) == ('active', 'read_only->active'), (state(t), events(t))
    return 'observed overlap, no code row, judged on active, refused'


def case_g():
    """No new blocking: the lifecycle job holds every subscription row it iterates until it commits,
    with the lock each writer's UPDATE already takes (FOR NO KEY UPDATE). A payment proof's foreign-key
    check takes FOR KEY SHARE on the subscription, which that lock admits; the statement below is the
    one PostgreSQL's RI check issues, and it must finish while the job is still open. A writer then
    proves the job really holds the row."""
    t, _ = tenant('active')
    sub = psql(f"select id from public.subscriptions where tenant_id='{t}';")
    a = session('_g_job', JOB)
    a.ready()
    b = session('_g_fk', f"""begin; set local lock_timeout='5s';
    select 1 from only public.subscriptions x where tenant_id='{t}' and id='{sub}' for key share of x;""")
    b.ready()
    c = session('_g_writer', f"begin; select app.platform_transition_subscription('{t}','grace_period','race');")
    wait_blocked(c, a)
    assert a.finish()[0] == 0
    assert b.finish()[0] == 0
    assert c.finish()[0] == 0
    assert (state(t), events(t)) == ('grace_period', 'active->grace_period'), (state(t), events(t))
    return 'key-share not blocked by the job; a writer was'


CASES = [
    ('SUSPENSION AFTER REDEMPTION', case_a),
    ('REDEMPTION AFTER SUSPENSION', case_b),
    ('LIFECYCLE AFTER RENEWAL', case_c),
    ('RENEWAL AFTER LIFECYCLE', case_d),
    ('LOCK ORDER', case_e),
    ('SUSPENSION AFTER RENEWAL', case_f),
    ('FOREIGN KEY CHECK DURING LIFECYCLE', case_g),
]


def main():
    failed = []
    for name, case in CASES:
        try:
            print(f'{name}: PASS ({case()})', flush=True)
        except Exception as e:  # each case is independent; report it and run the next
            failed.append(name)
            print(f'{name}: FAIL ({type(e).__name__}: {str(e).strip()[:300]})', flush=True)
        finally:
            while SESSIONS:
                release(SESSIONS.pop())
    # Fault isolation: no overlap above may surface as a lifecycle job failure for these tenants.
    findings = psql(f"""select count(*) from public.scheduled_job_findings f join public.tenants t on t.id = f.tenant_id
      where f.job_name = 'process_subscription_lifecycle' and t.slug like '{PREFIX}%';""")
    if findings == '0':
        print('LIFECYCLE FAULT ISOLATION: PASS (no job finding raised by any overlap)', flush=True)
    else:
        failed.append('LIFECYCLE FAULT ISOLATION')
        print(f'LIFECYCLE FAULT ISOLATION: FAIL ({findings} job findings)', flush=True)
    print(f'SUBSCRIPTION CONCURRENCY: {len(CASES) + 1 - len(failed)} passed, {len(failed)} failed', flush=True)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
