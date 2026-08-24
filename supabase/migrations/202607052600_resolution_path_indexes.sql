-- Migration: resolution_path_indexes
-- Plan reference: SPEC-147. Two index defects found by measuring the scope model against a realistic
-- dataset, plus the honest record of a third finding that turned out not to be one.
--
-- WHAT WAS MEASURED. 5,000 customers, 20,000 leads, 10,000 bookings, 25,000 booking items and 50,000
-- events, queried as a real authenticated employee. The scope model behaves as designed: the
-- resolution primitives are genuinely hoisted to InitPlans (visible in the plans as `(InitPlan n)`
-- and `(hashed SubPlan n)`), so they run once per query rather than once per row. Lead list 25 ms,
-- booking list 18 ms, owner tenant-wide list 9.6 ms, single-entity event read fully index-driven on
-- `events_tenant_entity_idx`.
--
-- `app.customer_timeline` costs ~128 ms warm, and isolating it shows where that goes:
--
--     as postgres, RLS bypassed .......    1.8 ms
--     as authenticated, RLS applied ...  260 ms  (first) / ~128 ms (warm)
--     subject fan-out alone ...........   64 ms
--
-- So essentially the entire cost is RLS resolution, paid once per scanned relation across the twelve
-- subject branches. That is inherent to a model where twelve tables each answer "may this caller see
-- this row?" -- not a defect in any one policy -- and 128 ms for a full Customer 360 is usable. The
-- two indexes below reduce the constant factor; the shape is sound.
--
-- A CORRECTION, RECORDED RATHER THAN QUIETLY DROPPED. The first reading of `customer_timeline` was
-- 611 ms, and a LATERAL rewrite was written to force an index-driven join. Measured fairly -- both
-- shapes warmed, three runs each, same session -- the join form and the LATERAL form are
-- indistinguishable (~128 ms each). The 611 ms and a subsequent 2,167 ms were cold-cache artefacts of
-- measuring the first statement after building 110,000 rows. The rewrite was reverted: a change with
-- no measured benefit, carrying a rationale that turned out to be false, is exactly the debt this
-- hardening pass exists to remove.

-- ---------------------------------------------------------------------------------------------
-- 1. The hottest lookup in the system had no index.
--
-- `app.current_tenant_id()` resolves `users.auth_user_id = auth.uid()`, and EVERY policy on EVERY
-- table calls it. `users` carries `(tenant_id, auth_user_id)`, which cannot serve this lookup --
-- the tenant is precisely what the function is trying to discover, so it is not available as a
-- leading key. The plan confirms a Seq Scan.
--
-- At 30 users that is free, which is why no test could have caught it. On Primary, `users` holds
-- every employee of every tenant, and this scan happens several times per request.
-- ---------------------------------------------------------------------------------------------
create index if not exists users_auth_user_id_idx
    on public.users (auth_user_id)
    where is_active;

-- ---------------------------------------------------------------------------------------------
-- 2. An exact duplicate index, added by SPEC-137.
--
-- `user_branch_assignments_one_primary_idx` already existed with the identical definition and the
-- identical partial predicate. SPEC-137 recorded "nothing stopped a user having two current primary
-- rows" and added a second, identical index -- the constraint it described was already enforced. The
-- CR's reasoning was right about why the rule matters and wrong about whether it was present.
--
-- A duplicate unique index is not harmless: every insert and update maintains both, and both are
-- checked. The one this repository added is the one removed.
-- ---------------------------------------------------------------------------------------------
drop index if exists public.user_branch_assignments_one_current_primary_idx;
