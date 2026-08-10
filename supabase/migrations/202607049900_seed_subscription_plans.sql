-- Migration: seed_subscription_plans
-- Repository audit (2026-08-10) found subscription_plans (202607042700) was never seeded by any
-- migration -- 202607043100's own header correctly excludes it as "seeded elsewhere" (a dedicated
-- table, same pattern as roles/permissions), but no "elsewhere" migration existed. 17_saas_plan_
-- matrix.md unambiguously names the three initial plans and their one-line descriptions; those are
-- seeded here verbatim. Per-plan feature/limit rows (feature_entitlements) are NOT seeded by this
-- migration -- canon 17's numeric limits table mixes "Unlimited"/"Custom" (non-numeric) values and
-- an "Enterprise includes all approved features" / "AI dashboard where approved" framing that does
-- not resolve unambiguously onto feature_entitlements' (is_enabled boolean, limit_value numeric)
-- shape without an invented interpretation; that gap is reported to the owner, not guessed here.
insert into subscription_plans (plan_code, name, description, is_active)
values
    ('starter',      'Starter',      'Starter is CRM-only.',                             true),
    ('professional',  'Professional', 'Professional includes operational workflow.',      true),
    ('enterprise',    'Enterprise',   'Enterprise includes all approved features.',       true)
on conflict (plan_code) do nothing;
