-- pgTAP: a subscription transition is judged on the row it replaces (SUB-4, SUB-5).
--
-- pgTAP has one session, so this file cannot race two writers. The races themselves are proven by
-- scripts/verify_subscription_concurrency.py, which holds one writer open, observes the other WAITING
-- through pg_blocking_pids, and asserts the final state and every recorded event. This file pins, in
-- every CI run, the shape that proof depends on:
--   * each of the three writers of public.subscriptions takes its row lock BEFORE canon 26 judges it,
--     with FOR NO KEY UPDATE, the lock its UPDATE already takes, so a payment proof's foreign-key
--     check is not made to wait;
--   * the Platform Owner's transition revokes activation codes before it locks the subscription, the
--     order a redemption takes (a reversed order deadlocked against a redemption);
--   * the lifecycle job judges the row it locked, never its loop snapshot, and locks inside its
--     per-row exception block, so a lock it cannot take fails one tenant, never the run;
--   * those three are still the only writers, so a new writer arrives with its own lock review.
create extension if not exists pgtap with schema extensions;

begin;
select plan(8);

create temporary table writer_src on commit drop as
select p.proname::text as fn, p.prosrc as src
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'app'
  and p.proname in ('platform_activate_subscription', 'platform_transition_subscription',
                    'process_subscription_lifecycle');

select ok((select src from writer_src where fn = 'platform_activate_subscription')
          ~ 'from public\.subscriptions\s+where tenant_id = p_tenant_id\s+order by created_at desc\s+limit 1\s+for no key update;',
  'SUB-4: app.platform_activate_subscription locks the subscription it judges');

select ok((select src from writer_src where fn = 'platform_transition_subscription')
          ~ 'from public\.subscriptions\s+where tenant_id = p_tenant_id\s+order by created_at desc\s+limit 1\s+for no key update;',
  'SUB-4: app.platform_transition_subscription locks the subscription it judges');

select ok((select strpos(src, 'perform app.platform_revoke_license_tokens(') > 0
              and strpos(src, 'perform app.platform_revoke_license_tokens(') < strpos(src, 'from public.subscriptions')
           from writer_src where fn = 'platform_transition_subscription'),
  'Lock order: the transition revokes activation codes before it locks the subscription');

select ok((select src from writer_src where fn = 'process_subscription_lifecycle')
          ~ 'from public\.subscriptions\s+where id = r\.id\s+for no key update;',
  'SUB-5: the lifecycle job re-reads each subscription under its lock');

select ok((select src !~ '\mr\.(subscription_status_code|ends_at|grace_ends_at|auto_renew|billing_period_code)\M'
           from writer_src where fn = 'process_subscription_lifecycle'),
  'SUB-5: the lifecycle job judges the locked row, never its loop snapshot');

select ok((select src ~ '\mloop\s+begin\s+(--[^\n]*\s+)*select subscription_status_code[^;]*\mwhere id = r\.id\s+for no key update;'
              and strpos(src, 'for no key update') < strpos(src, 'exception when others')
           from writer_src where fn = 'process_subscription_lifecycle'),
  'Fault isolation: the lifecycle lock is taken inside the per-row exception block');

select is((select count(*)::int from writer_src where src ~* '\mfor update\M'), 0,
  'Lock strength: no writer takes FOR UPDATE, which would make a payment proof''s key-share check wait');

select is((select array_agg(n.nspname || '.' || p.proname order by n.nspname, p.proname)
           from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname in ('app', 'public', 'reporting')
             and p.prosrc ~* 'update\s+public\.subscriptions\M'),
  array['app.platform_activate_subscription', 'app.platform_transition_subscription',
        'app.process_subscription_lifecycle'],
  'The three locked writers are still the only functions that update public.subscriptions');

select * from finish();
rollback;
