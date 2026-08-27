-- pgTAP: POL-1 -- every RLS policy names the role it applies to, and that role is `authenticated`.
--
-- WHY THIS GUARD EXISTS. `create policy ... using (...)` with no `to` clause defaults to PUBLIC.
-- That is easy to write, invisible in review, and produces a policy that applies to every role
-- rather than to signed-in users. Four policies drifted that way across two packages before the
-- WP-04-D sweep grouped `pg_policies.roles` and saw 113 against 4.
--
-- None of the four was exploitable -- `anon` holds no privilege on any table here, and a policy
-- cannot grant what no GRANT permits. This guard is not about that. It is about the fact that the
-- defect arrives from an OMISSION rather than from a decision, and that the day some role other
-- than `authenticated` is granted a privilege, every `public`-scoped policy silently extends to it
-- while its correctly-scoped siblings do not. Cheaper to make unwritable than to re-find.
--
-- Assertion 2 is the positive control. Assertion 1 counts something it wants to be zero, and a
-- zero that comes from an empty universe proves nothing at all.
create extension if not exists pgtap with schema extensions;

begin;
select plan(5);

select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public' and 'public' = any (roles)),
  0,
  'no policy in the public schema applies to PUBLIC -- every one names authenticated');

select ok(
  (select count(*) from pg_policies
    where schemaname = 'public' and roles = array['authenticated']::name[]) > 100,
  'POSITIVE CONTROL: 100+ policies exist and every one of them names authenticated');

select is(
  (select count(*)::int from pg_policies
    where schemaname = 'storage' and 'public' = any (roles)),
  0,
  '...and the object-store policies follow the same rule -- the bytes are not a special case');

-- =============================================================================================
-- 4-5. `alter policy ... to authenticated` must have changed the ROLE LIST AND NOTHING ELSE.
--      Retranscribing these expressions is what produced PP-2, so the migration deliberately did
--      not retranscribe them -- and these two assertions are what prove that claim rather than
--      asserting it in a comment.
-- =============================================================================================
select is(
  (select count(*)::int from (
      select unnest(array['booking_id','booking_item_id','invoice_id','quotation_id','receipt_id',
                          'passenger_id','supplier_id','subscription_payment_proof_id',
                          'has_tenant_wide_read']) as needle) n
    where position(n.needle in (
      select pg_get_expr(pol.polqual, pol.polrelid)
      from pg_policy pol join pg_class c on c.oid = pol.polrelid
      where c.relname = 'document_links' and pol.polname = 'scope_isolation')) = 0),
  0,
  'all nine document_links branches survive the role-scope change untouched');

select ok(
  (select pg_get_expr(pol.polqual, pol.polrelid)
     from pg_policy pol join pg_class c on c.oid = pol.polrelid
    where c.relname = 'subscription_payment_proofs' and pol.polname = 'scope_read')
    like '%VIEW_SUBSCRIPTION_STATUS%'
  and (select pg_get_expr(pol.polwithcheck, pol.polrelid)
         from pg_policy pol join pg_class c on c.oid = pol.polrelid
        where c.relname = 'subscription_payment_proofs' and pol.polname = 'scope_insert')
    like '%MANAGE_TENANT_SETTINGS%',
  '...and SPP-1/SPP-2''s permission requirements survive it too');

select finish();
rollback;
