-- Migration: register_refund_lifecycle_events
-- Repository audit (2026-08-10) found app.advance_refund (202607047600) emits
-- refund_approved/refund_rejected/refund_cancelled/refund_processing for real, canonical
-- refund_status_code transitions (requested/approved/rejected/processing/completed/cancelled --
-- 25_catalog_registry.md, seeded verbatim in 202607043100) that were never registered as events.
-- 202607047600's own header already documents "Emits refund_approved/rejected/processing/
-- completed/cancelled" -- the RPC and its states are canonical; only the event-catalog
-- registration was incomplete (canon 27 had refund_requested/refund_completed only). 6 of the
-- RPC's 8 transitions aborted with "unknown event_type_code" once 202607049100 hardened
-- app.record_event (reproduced live against a clean db reset). This migration completes the
-- registration canon 27 now carries (refund_approved/rejected/cancelled/processing, Severity:
-- info, matching what the RPC has always emitted) -- the RPC itself is unchanged.
insert into catalog_values (catalog_type_code, code, label, sort_order, is_system, is_active)
values
    ('event_type', 'refund_approved',   'Refund Approved',   166, true, true),
    ('event_type', 'refund_rejected',   'Refund Rejected',   167, true, true),
    ('event_type', 'refund_cancelled',  'Refund Cancelled',  168, true, true),
    ('event_type', 'refund_processing', 'Refund Processing', 169, true, true)
on conflict (catalog_type_code, code) do nothing;
