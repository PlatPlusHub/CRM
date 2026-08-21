-- Migration: approval_request_subject_integrity
-- Plan reference: SPEC-135. Resolves REL-2 — `approval_requests` carried two representations of the
-- same fact with nothing forcing them to agree.
--
-- THE AMBIGUITY. The table has a polymorphic subject (`related_entity_type` / `related_entity_id`)
-- AND typed foreign keys (`booking_item_id`, `document_id`). `app.request_finance_approval` writes
-- both with the same value, but `app.review_finance_approval` **joins on `booking_item_id`** and
-- acts on it. Nothing prevented a row where `related_entity_type = 'booking_item'`,
-- `related_entity_id = X`, and `booking_item_id = Y`. The reviewer would then approve Y while the
-- audit trail said the request was about X — a silent divergence in a finance-approval path.
--
-- WHICH IS AUTHORITATIVE, decided from canon rather than preference. `31_schema_draft.md` lists
-- `approval_requests` core fields and marks the optional ones explicitly — "reviewed_by nullable",
-- "booking_item_id nullable", "document_id nullable" — while listing `related_entity_type` and
-- `related_entity_id` WITHOUT that marker. Canon also describes the table as a "Generic approval
-- workflow" supporting seven approval types, only two of which have a typed column at all
-- (`refund_approval`, `discount_approval`, `booking_override`, `manual_price_change`,
-- `sensitive_data_change` and `subscription_approval` have none).
--
-- So: **the polymorphic pair is the subject; the typed FKs are typed accessors for the two subjects
-- that need relational joins.** That resolves REL-2 without removing either representation and
-- without a canon amendment — the typed columns keep earning their place (indexes, joins, the
-- `review_finance_approval` path), they simply stop being able to disagree.
--
-- TWO DEFECTS ARE CLOSED HERE:
--   1. Canon drift — the subject columns are nullable in the implementation while canon lists them
--      as core. An approval request is always *about* something; there is no such thing as an
--      approval of nothing.
--   2. The divergence itself — a typed FK, when present, must name exactly the same row the
--      polymorphic subject names.
--
-- Safe at zero rows; both would require data reconciliation once approvals exist, which is precisely
-- the kind of retrofit this gate exists to avoid.

-- 1. The subject is mandatory. SPEC-130's trigger already enforces that the pair is set together and
--    points at a real same-tenant row; this makes "set" unconditional, per canon.
alter table public.approval_requests
    alter column related_entity_type set not null,
    alter column related_entity_id set not null;

-- 2. A typed accessor may only be a typed view of the authoritative subject.
alter table public.approval_requests
    add constraint approval_requests_subject_consistency_chk
    check (
        (booking_item_id is null
         or (related_entity_type = 'booking_item' and related_entity_id = booking_item_id))
        and
        (document_id is null
         or (related_entity_type = 'document' and related_entity_id = document_id))
    );

-- 3. One subject, so the two typed accessors are mutually exclusive. This mirrors the CHECK
--    `document_links` already uses to enforce exactly-one-target, keeping the two polymorphic-ish
--    tables consistent with each other.
alter table public.approval_requests
    add constraint approval_requests_single_typed_subject_chk
    check (num_nonnulls(booking_item_id, document_id) <= 1);

comment on column public.approval_requests.related_entity_type is
    'AUTHORITATIVE subject of the approval, per 31_schema_draft.md core fields. booking_item_id and document_id are typed accessors for the two subjects that need relational joins, and are constrained to agree with this pair (SPEC-135 / REL-2).';
