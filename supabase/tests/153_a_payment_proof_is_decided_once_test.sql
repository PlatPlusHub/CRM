-- pgTAP: a subscription payment proof is decided once (SPP-6).
--
-- pgTAP has one session, so this file cannot race two reviews. The races themselves are proven by
-- scripts/verify_subscription_concurrency.py, which holds one review open, observes the other WAITING
-- through pg_blocking_pids, and asserts the final proof, subscription, events and security events.
-- This file pins, in every CI run, the shape that proof depends on:
--   * app.platform_review_payment_proof locks the proof it judges, with FOR NO KEY UPDATE, the lock
--     its UPDATE already takes, BEFORE the `pending` check, so a waiting review re-reads the decision;
--   * it takes no FOR UPDATE, which would make a document link's key-share check on the proof wait;
--   * it is still the only function that updates the table, so the lock order it states (the proof,
--     then the subscription) has no reversed writer, and a new writer arrives with its own review;
--   * it is still the platform's: SECURITY DEFINER, an empty search_path, executable by service_role
--     and by no tenant role.
create extension if not exists pgtap with schema extensions;

begin;
select plan(5);

create temporary table review_src on commit drop as
select p.prosrc as src
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'app' and p.proname = 'platform_review_payment_proof';

select ok((select src from review_src)
          ~ 'select id, tenant_id, subscription_id, status_code\s+into v_proof\s+from public\.subscription_payment_proofs\s+where id = p_proof_id\s+for no key update;',
  'SPP-6: app.platform_review_payment_proof locks the proof it judges');

select ok((select strpos(src, 'for no key update') > 0
              and strpos(src, 'for no key update') < strpos(src, 'if v_proof.status_code <> ''pending'' then')
           from review_src),
  'SPP-6: the proof is locked before the pending check judges it');

select ok((select src !~* '\mfor update\M' from review_src),
  'Lock strength: the review takes no FOR UPDATE, which would make a document link''s key-share check wait');

select is((select array_agg(n.nspname || '.' || p.proname order by n.nspname, p.proname)
           from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('app', 'public', 'reporting')
             and p.prosrc ~* 'update\s+public\.subscription_payment_proofs\M'),
  array['app.platform_review_payment_proof'],
  'The locked review is still the only function that updates public.subscription_payment_proofs');

select ok((select p.prosecdef and p.proconfig = array['search_path=""']
              and has_function_privilege('service_role', p.oid, 'EXECUTE')
              and not has_function_privilege('authenticated', p.oid, 'EXECUTE')
              and not has_function_privilege('anon', p.oid, 'EXECUTE')
           from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'app' and p.proname = 'platform_review_payment_proof'),
  'The review is still the platform''s: SECURITY DEFINER, empty search_path, service_role only');

select * from finish();
rollback;
