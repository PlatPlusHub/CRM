"""Two-session proofs that a subscription transition is judged on the row it replaces (SUB-4, SUB-5),
and that a payment proof is decided once (SPP-6).

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


def upload(owner):
    return f"""begin; set local role authenticated;
    select set_config('request.jwt.claims','{{"sub":"{owner}","aal":"aal2"}}',true);
    select app.upload_subscription_payment_proof('renewal.pdf','pdf',1024,'race');"""


def proof(owner):
    return psql(upload(owner) + "commit;").splitlines()[-1]


def review(p, approve, period=None):
    # The platform path: service_role, session-less, with terms only when a period is given.
    terms = f",'professional','{period}'" if period else ''
    return f"begin; set local role service_role; select app.platform_review_payment_proof('{p}',{approve},'race'{terms});"


def decided(t):
    """proof states | subscription state/period | review and activation events | security decisions"""
    return psql(f"""select concat_ws(' | ',
      (select string_agg(status_code, ',' order by status_code) from public.subscription_payment_proofs where tenant_id='{t}'),
      (select subscription_status_code || '/' || coalesce(billing_period_code, '-') from public.subscriptions where tenant_id='{t}'),
      coalesce((select string_agg(event_type_code || ':' || coalesce(previous_state, '-') || '->' || new_state, ',' order by seq)
        from public.events where tenant_id='{t}' and entity_type='subscription'
         and event_type_code <> 'subscription_payment_proof_uploaded'), '-'),
      coalesce((select string_agg(payload->>'decision', ',' order by seq) from public.security_events
        where tenant_id='{t}' and security_event_type_code='subscription_payment_reviewed'), '-'));""")


# A tenant paying its renewal in its grace period (no grace end set), so its writes stay open: a proof
# fixture left read_only would block every later suite's cross-tenant write to its documents' policies.
PAYING = 'grace_period'
APPROVED = 'subscription_payment_approved:pending->approved'
REJECTED = 'subscription_payment_rejected:pending->rejected'
ACTIVATED = 'subscription_activated:grace_period->active'


def refused_as(out, status):
    return f'payment proof is already {status}, only a pending proof can be reviewed' in out


def race(first, second, refused):
    """A holds its review open; B's review of the same proof must WAIT on A, then be refused."""
    a = session('_first', first)
    a.ready()
    b = session('_second', second)
    wait_blocked(b, a)
    assert a.finish()[0] == 0
    rc, out = b.finish()
    assert rc != 0 and refused_as(out, refused), f'second review not refused as {refused}: rc={rc} out={out!r}'


def case_h():
    """SPP-6: an approval with terms commits while a rejection waits. The rejection must re-read the
    approved proof and be refused, never leave a rejected proof behind an activated subscription."""
    t, owner = tenant(PAYING)
    p = proof(owner)
    race(review(p, 'true', 'annual'), review(p, 'false'), 'approved')
    assert decided(t) == f'approved | active/annual | {APPROVED},{ACTIVATED} | approved', decided(t)
    return 'observed overlap, rejection refused, one decision, one activation'


def case_i():
    """SPP-6: a rejection commits while an approval with terms waits. The approval must be refused;
    canon 26 has no move from rejected to approved, and the tenant is not activated."""
    t, owner = tenant(PAYING)
    p = proof(owner)
    race(review(p, 'false'), review(p, 'true', 'annual'), 'rejected')
    assert decided(t) == f'rejected | grace_period/- | {REJECTED} | rejected', decided(t)
    return 'observed overlap, approval refused, not activated'


def case_j():
    """SPP-6: two approvals with different terms. The second must be refused, so the first
    reviewer's terms stand and the tenant is activated once."""
    t, owner = tenant(PAYING)
    p = proof(owner)
    race(review(p, 'true', 'annual'), review(p, 'true', 'monthly'), 'approved')
    assert decided(t) == f'approved | active/annual | {APPROVED},{ACTIVATED} | approved', decided(t)
    return "observed overlap, second approval refused, first reviewer's terms kept"


def case_k():
    """The lock never decides by itself: a review that rolls back releases the waiting review, which
    re-reads the proof as pending and decides it, once."""
    t, owner = tenant(PAYING)
    p = proof(owner)
    a = session('_k_rollback', review(p, 'true', 'annual'))
    a.ready()
    b = session('_k_reject', review(p, 'false'))
    wait_blocked(b, a)
    assert a.finish('rollback;')[0] == 0
    rc, out = b.finish()
    assert rc == 0, f'the released review failed: {out!r}'
    assert decided(t) == f'rejected | grace_period/- | {REJECTED} | rejected', decided(t)
    return 'observed overlap, rollback released the waiter, one decision'


def case_l():
    """No new blocking: a review holds the proof and the subscription until it commits. A tenant's
    new upload, whose foreign-key check takes FOR KEY SHARE on the subscription, and a document link
    to the held proof, whose check takes FOR KEY SHARE on the proof (the statement below is the one
    PostgreSQL's RI check issues), must both finish while the review is open. A second review proves
    the review really holds the proof."""
    t, owner = tenant(PAYING)
    p = proof(owner)
    a = session('_l_review', review(p, 'true', 'annual'))
    a.ready()
    b = session('_l_upload', "set lock_timeout='5s';\n" + upload(owner))
    b.ready()
    c = session('_l_fk', f"""begin; set local lock_timeout='5s';
    select 1 from only public.subscription_payment_proofs x where tenant_id='{t}' and id='{p}' for key share of x;""")
    c.ready()
    d = session('_l_review2', review(p, 'false'))
    wait_blocked(d, a)
    assert a.finish()[0] == 0
    assert b.finish()[0] == 0
    assert c.finish()[0] == 0
    rc, out = d.finish()
    assert rc != 0 and refused_as(out, 'approved'), f'second review not refused: rc={rc} out={out!r}'
    assert decided(t) == f'approved,pending | active/annual | {APPROVED},{ACTIVATED} | approved', decided(t)
    return 'upload and key-share not blocked by the review; a second review was'


def case_m():
    """Lock order: the lifecycle job holds the tenant's subscription row while a review with terms
    starts. The review locks the proof, then waits on the subscription inside the activation; the job
    never touches a proof, so the review completes once the job commits, without a deadlock."""
    t, owner = tenant(PAYING)
    p = proof(owner)
    a = session('_m_job', JOB)
    a.ready()
    b = session('_m_review', review(p, 'true', 'annual'))
    wait_blocked(b, a)
    assert a.finish()[0] == 0
    rc, out = b.finish()
    assert 'deadlock' not in out and rc == 0, f'the review failed: rc={rc} out={out!r}'
    assert decided(t) == f'approved | active/annual | {APPROVED},{ACTIVATED} | approved', decided(t)
    return 'review waited on the subscription, no deadlock, decided once'


def case_n():
    """Controls, one session at a time: a review whose activation fails rolls back with its decision;
    a single approval and a single rejection each decide once; a later review of either is refused."""
    t, owner = tenant(PAYING)
    p = proof(owner)
    rc, out = session('_n_fail', review(p, 'true', 'annual').replace("'professional'", "'no-such-plan'")).finish()
    assert rc != 0 and 'unknown or inactive plan_code' in out, f'activation did not fail: rc={rc} out={out!r}'
    assert decided(t) == 'pending | grace_period/- | - | -', f'a failed activation kept its decision: {decided(t)}'
    rc, out = session('_n_approve', review(p, 'true', 'annual')).finish()
    assert rc == 0, out
    rc, out = session('_n_again', review(p, 'true', 'monthly')).finish()
    assert rc != 0 and refused_as(out, 'approved'), f'replayed approval not refused: rc={rc} out={out!r}'
    assert decided(t) == f'approved | active/annual | {APPROVED},{ACTIVATED} | approved', decided(t)
    u, owner2 = tenant(PAYING)
    q = proof(owner2)
    rc, out = session('_n_reject', review(q, 'false')).finish()
    assert rc == 0, out
    rc, out = session('_n_late', review(q, 'true', 'annual')).finish()
    assert rc != 0 and refused_as(out, 'rejected'), f'approval of a rejected proof not refused: rc={rc} out={out!r}'
    assert decided(u) == f'rejected | grace_period/- | {REJECTED} | rejected', decided(u)
    return 'failed activation rolled back; single decisions held; replays refused'


CASES = [
    ('SUSPENSION AFTER REDEMPTION', case_a),
    ('REDEMPTION AFTER SUSPENSION', case_b),
    ('LIFECYCLE AFTER RENEWAL', case_c),
    ('RENEWAL AFTER LIFECYCLE', case_d),
    ('LOCK ORDER', case_e),
    ('SUSPENSION AFTER RENEWAL', case_f),
    ('FOREIGN KEY CHECK DURING LIFECYCLE', case_g),
    ('REJECTION AFTER APPROVAL', case_h),
    ('APPROVAL AFTER REJECTION', case_i),
    ('APPROVAL AFTER APPROVAL', case_j),
    ('REVIEW AFTER ROLLED-BACK REVIEW', case_k),
    ('UPLOAD DURING REVIEW', case_l),
    ('REVIEW DURING LIFECYCLE', case_m),
    ('SINGLE REVIEWS', case_n),
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
