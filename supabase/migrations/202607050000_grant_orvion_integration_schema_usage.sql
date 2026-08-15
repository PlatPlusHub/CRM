-- Migration: grant_orvion_integration_schema_usage (SPEC-122)
-- Fixes a real, dynamically-confirmed Phase-8 blocker: orvion_integration (mig 202607049200) has
-- function-level EXECUTE grants on all 4 of its RPCs (app.map_outcomes_to_conversions,
-- app.capture_attribution_click, app.claim_conversion_deliveries,
-- app.record_conversion_delivery_result) but was never granted USAGE on the app schema itself.
-- Schema USAGE is a prerequisite Postgres privilege independent of function-level grants — without
-- it, the role cannot call any of its granted functions at all. Confirmed by an internal pipeline
-- test session 2026-08-15 (local dev DB, rolled back): the first call as orvion_integration failed
-- with "permission denied for schema app" despite the correct EXECUTE grant already existing.
-- Precedent: migration 202607043700 granted the same schema USAGE to service_role for the same
-- reason (provision_tenant is service_role-only).

grant usage on schema app to orvion_integration;
