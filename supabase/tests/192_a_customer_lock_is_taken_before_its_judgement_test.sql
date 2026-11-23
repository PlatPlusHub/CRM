-- pgTAP: a customer row is locked before the decision that reads it (CUST-10, CUST-12).
--
-- EC-7: every repaired finding keeps a permanent guard. CUST-10 (migration 20260909060754) and CUST-12
--   (20260909114354) fixed two races by a row lock, and only scripts/verify_customer_concurrency.py proves
--   them; no workflow, Finish profile or script runs it, and pgTAP has one session, so no test noticed a
--   lost lock. As Tests 148 (SUB-4, SUB-5) and 153 (SPP-6) do, this file pins in every CI run the shape
--   the race proof depends on:
--   * app.merge_customer_identity locks both identities in id order before it reads either lifecycle
--     state, so opposite merges cannot each validate a stale row version and archive both survivors;
--   * app.evaluate_customer_credit_threshold locks the customer before it aggregates the exposure and
--     reads the last threshold event, so two concurrent evaluations cannot both record a crossing.
--   Each function exists exactly once; a missing or overloaded function fails its assertions.
create extension if not exists pgtap with schema extensions;

begin;
select plan(4);

create temporary table customer_lock_src on commit drop as
select p.proname::text as fn, p.prosrc as src
from pg_proc p join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'app'
  and p.proname in ('merge_customer_identity', 'evaluate_customer_credit_threshold');

select ok((select count(*) = 1 and bool_and(src
              ~ 'perform 1 from public\.customers\s+where tenant_id = v_tenant and id in \(p_source_customer_id, p_target_customer_id\)\s+order by id for update;')
           from customer_lock_src where fn = 'merge_customer_identity'),
  'CUST-12: app.merge_customer_identity locks both identities in id order');

select ok((select count(*) = 1 and bool_and(strpos(src, 'order by id for update;') > 0
              and strpos(src, 'order by id for update;') < strpos(src, 'select is_archived into v_src_archived')
              and strpos(src, 'order by id for update;') < strpos(src, 'select is_archived into v_target_archived'))
           from customer_lock_src where fn = 'merge_customer_identity'),
  'CUST-12: the merge takes its lock before it reads either lifecycle state');

select ok((select count(*) = 1 and bool_and(src
              ~ 'from public\.customers c\s+where c\.id=p_customer_id and c\.tenant_id=p_tenant_id for update;')
           from customer_lock_src where fn = 'evaluate_customer_credit_threshold'),
  'CUST-10: app.evaluate_customer_credit_threshold locks the customer it judges');

select ok((select count(*) = 1 and bool_and(strpos(src, 'c.tenant_id=p_tenant_id for update;') > 0
              and strpos(src, 'c.tenant_id=p_tenant_id for update;') < strpos(src, 'app.customer_exposure_in_limit_currency(')
              and strpos(src, 'c.tenant_id=p_tenant_id for update;') < strpos(src, 'from public.events e'))
           from customer_lock_src where fn = 'evaluate_customer_credit_threshold'),
  'CUST-10: the evaluation takes its lock before the exposure and the last threshold event');

select * from finish();
rollback;
