-- POL-1 -- four RLS policies apply `to public` while the other 113 apply `to authenticated`.
--
-- FOUND BY: the WP-04-D discovery sweep, grouping `pg_policies.roles` across the whole `public`
-- schema. 113 policies name `authenticated`; four name `public`:
--
--     document_links.scope_isolation                  (202607054700, WP-04-C -- mine)
--     subscription_payment_proofs.scope_read          (202607054800, WP-04-C -- mine)
--     subscription_payment_proofs.scope_insert        (202607054800, WP-04-C -- mine)
--     tenant_license_activations.platform_only        (202607054100, SPEC-158 -- mine)
--
-- All four are mine, from the last two packages, and all four have the same cause: I wrote
-- `create policy ... for select using (...)` and omitted the `to authenticated` clause, which
-- PostgreSQL then defaults to `PUBLIC`. `subscription_payment_proofs` shows the drift most plainly
-- -- `scope_update` (written earlier, by WP-04-B) is `to authenticated` while the two policies I
-- added beside it are not. One table, two conventions.
--
-- IS IT EXPLOITABLE TODAY? No, and that is stated rather than used as a reason to leave it. A
-- `public` policy applies to every non-BYPASSRLS role, which here means it additionally applies to
-- `anon` -- and `anon` holds no privilege on any table in this schema (SPEC-124 revoked the hosted
-- default ACL, and `10_grant_model_test.sql` keeps it revoked). A policy cannot grant access that
-- no GRANT permits, so nothing is reachable through this today.
--
-- WHY IT IS FIXED ANYWAY. It is an avoidable engineering defect, and "not currently blocking" is
-- not a reason to keep one. Concretely it costs three things:
--   * It makes the authorization surface unreadable -- 113 policies say "authenticated users may do
--     X"; four say "anyone may do X", and a reader must go and prove the grants to learn that those
--     two sentences mean the same thing here.
--   * It is one GRANT away from mattering. The day any role other than `authenticated` is given a
--     privilege on these tables, these four policies silently extend to it while their 113 siblings
--     correctly do not. That is a defect that arrives without anyone editing the policy.
--   * It is a CLASS, not an incident -- four occurrences across two packages from one omitted
--     clause -- so it gets a guard, not just a patch. See `50_policy_role_scope_test.sql`.
--
-- WHY `alter policy` AND NOT drop/recreate. The expressions are not touched at all. Retranscribing
-- `document_links.scope_isolation` would mean copying ten branches by hand for the second time in
-- two migrations, and PP-2 exists precisely because a branch went missing during a retranscription.
-- `alter policy ... to authenticated` changes the role list and provably nothing else.
--
-- A deny-all policy scoped to `authenticated` is not weaker than one scoped to `public`: RLS
-- default-denies when no policy matches the acting role, so for every other role the outcome is
-- identical refusal. `tenant_license_activations` is therefore included, for uniformity, with no
-- change in effect.

alter policy scope_isolation on public.document_links                to authenticated;
alter policy scope_read      on public.subscription_payment_proofs   to authenticated;
alter policy scope_insert    on public.subscription_payment_proofs   to authenticated;
alter policy platform_only   on public.tenant_license_activations    to authenticated;
