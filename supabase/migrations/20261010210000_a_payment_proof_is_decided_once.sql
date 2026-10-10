-- SPEC-261: a subscription payment proof is decided once. Two platform reviews of the same proof
-- can no longer both pass the `pending` check (SPP-6).
--
-- Canon 26's approval machine decides a proof only from `pending`, and canon 28 makes that decision
-- the Platform Owner's. `app.platform_review_payment_proof` (WP-04-B, `202607054500`) read the proof
-- without a lock, judged `pending` on that read and then updated the row by id alone. Under READ
-- COMMITTED a second review read the first's uncommitted row as `pending`, waited only at its UPDATE,
-- and then rewrote the decided row, because `where id = ...` still matched.
--
-- SPP-6, measured at `39ab45a` on the local stack with two live sessions, the waiter observed through
-- `pg_blocking_pids`:
--   * an approval with terms committed while a rejection waited: the proof ended `rejected` with the
--     subscription `active` on the approval's terms, and the events read approved, activated, then
--     rejected "from pending";
--   * a rejection committed while an approval with terms waited: the rejected proof ended `approved`
--     and the subscription was activated, a move canon 26 does not have;
--   * two approvals with different terms each recorded an approval and an activation, and the second
--     reviewer's terms replaced the first's.
--
-- THE REPAIR replaces only this function's body, adding `for no key update` to its one read of the
-- proof. It is the lock the UPDATE below already takes, taken before the judgement instead of after
-- it, so a waiting review re-reads the committed row and the existing check refuses it. Nothing else
-- moves: the lock order (the proof, then the subscription inside `app.platform_activate_subscription`)
-- is the order the UPDATE already imposed, and `for no key update` admits the `for key share` that a
-- `document_links` foreign-key check takes on the proof. Signature, SECURITY DEFINER, owner,
-- `search_path`, ACL, events, security events and activation are unchanged.
create or replace function app.platform_review_payment_proof(
    p_proof_id uuid,
    p_approve boolean,
    p_notes text default null,
    p_plan_code text default null,
    p_billing_period_code text default null,
    p_auto_renew boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_proof record;
    v_new_status text;
begin
    -- SPP-6: the proof is locked BEFORE it is judged. Under READ COMMITTED, FOR NO KEY UPDATE waits
    -- for a concurrent review and then returns the row it committed, so a second review sees the
    -- decision and is refused below instead of overwriting it.
    select id, tenant_id, subscription_id, status_code
      into v_proof
    from public.subscription_payment_proofs
    where id = p_proof_id
    for no key update;
    if not found then
        raise exception 'unknown payment proof %', p_proof_id;
    end if;

    -- Canon 26's approval machine: only a PENDING proof can be decided. This also makes review
    -- idempotent-safe -- a second approval of the same proof is refused rather than silently
    -- re-activating a subscription.
    if v_proof.status_code <> 'pending' then
        raise exception 'payment proof is already %, only a pending proof can be reviewed',
            v_proof.status_code using errcode = 'check_violation';
    end if;

    v_new_status := case when p_approve then 'approved' else 'rejected' end;

    update public.subscription_payment_proofs
       set status_code  = v_new_status,
           reviewed_at  = now(),
           review_notes = coalesce(p_notes, review_notes)
     where id = p_proof_id;

    perform app.record_event(
        v_proof.tenant_id,
        case when p_approve then 'subscription_payment_approved'
             else 'subscription_payment_rejected' end,
        'subscription', v_proof.subscription_id, null,
        'pending', v_new_status, p_notes,
        jsonb_build_object('proof_id', p_proof_id),
        'info'
    );

    insert into public.security_events (tenant_id, security_event_type_code, payload)
    values (v_proof.tenant_id, 'subscription_payment_reviewed',
            jsonb_build_object('proof_id', p_proof_id, 'decision', v_new_status));

    -- Activation only when the Platform Owner supplied the terms. Delegated rather than reimplemented
    -- so the canon-26 transition check, the end-date derivation and the lifetime rule keep exactly
    -- one home (SPEC-157).
    if p_approve and p_plan_code is not null and p_billing_period_code is not null then
        perform app.platform_activate_subscription(
            v_proof.tenant_id, p_plan_code, p_billing_period_code, p_auto_renew);
    end if;
end;
$fn$;
