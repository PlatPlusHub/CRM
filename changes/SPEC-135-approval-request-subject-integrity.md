# Change Request — SPEC-135

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Establish which representation of an approval request's subject is authoritative, and make the other one incapable of disagreeing with it.

---

## Business Reason

`approval_requests` carried two representations of the same fact: a polymorphic subject (`related_entity_type` / `related_entity_id`) and typed foreign keys (`booking_item_id`, `document_id`). `app.request_finance_approval` writes both with the same value — but `app.review_finance_approval` **joins on `booking_item_id`** and acts on it.

Nothing prevented a row where `related_entity_type = 'booking_item'`, `related_entity_id = X` and `booking_item_id = Y`. The reviewer would then approve **Y** while the audit trail recorded the request as being about **X** — a silent divergence on a finance-approval path, which is the worst place for one.

REL-2 was previously deferred on the reasoning that there are zero rows and therefore no divergence yet. That is exactly the reasoning this gate exists to reject: the fix is free now and requires data reconciliation later.

---

## Risks

Very low. Zero rows. Both representations are retained — the typed accessors keep earning their place (indexes, joins, the existing `review_finance_approval` path); they simply become incapable of disagreeing with the subject.

---

## Supersedes / Depends On

Depends on `changes/SPEC-130-enforce-entity-references.md`, whose trigger already guarantees the polymorphic subject names a real same-tenant row. Resolves REL-2.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607051200_approval_request_subject_integrity.sql`
- `supabase/tests/20_approval_subject_integrity_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-135-approval-request-subject-integrity.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- `_ORVION_CANONICAL/31_schema_draft.md` — **not amended.** Canon already states the answer; this CR implements it rather than changing it.
- `supabase/migrations/202607046000_request_finance_approval.sql` and `202607046100_review_finance_approval.sql` — both already write and read consistently, so neither needed redefining.

---

## Minimum Reading List

- `_ORVION_CANONICAL/31_schema_draft.md` §approval_requests
- `supabase/migrations/202607046000_request_finance_approval.sql`
- `supabase/migrations/202607046100_review_finance_approval.sql`
- `supabase/migrations/202607042800_create_document_links_table.sql` (the exactly-one-target CHECK precedent)

---

## Implementation Steps

1. Verification check: `approval_requests.related_entity_type` is NOT NULL. If nullable, set both subject columns NOT NULL per canon.
2. Verification check: `approval_requests_subject_consistency_chk` exists. If absent, add the CHECK requiring each typed accessor, when present, to match both the subject type and the subject id.
3. Verification check: `approval_requests_single_typed_subject_chk` exists. If absent, add the mutual-exclusion CHECK.
4. Verification check: `db reset` replays clean, smoke passes, suite passes, Primary agrees by fingerprint.

---

## Acceptance Criteria

- [x] A typed accessor naming a **different row** than the subject is refused.
- [x] A typed accessor whose subject **type** disagrees is refused by the consistency CHECK specifically.
- [x] An approval request with **no subject at all** is refused.
- [x] The agreeing representation — exactly what `request_finance_approval` writes — still succeeds.
- [x] An approval type with no typed accessor still works through the polymorphic subject alone.
- [x] Suite 20 files / 126 tests PASS; smoke passes; repo = local = Primary (101 migrations).

---

## Execution Log

### 2026-08-21 — Claude Opus 5 (foundation freeze gate)

Outcome: Complete

All steps applied. `db reset` 101 clean; smoke `ALL CHECKS PASSED`; `Files=20, Tests=126 … PASS`. Primary: ledger `b82e374ce2771248b7b998a7a9bd9473`, CHECK constraints 21 → 24.

---

## Verification Notes

### 2026-08-21 — Claude Opus 5 (foundation freeze gate)

Verdict: Confirmed Complete

Findings: One negative case had to be rewritten before it proved anything, and the reason is recorded in the test itself. The first draft of "a typed accessor whose subject type disagrees" used a subject id that did not exist, so **SPEC-130's entity-reference trigger caught it first with `23503`** — the write was correctly refused, but by a different guard, which means the assertion would have passed while testing nothing about this migration. Rewritten to use a real booking as the subject, so SPEC-130 passes the row through and this migration's CHECK is the thing that must fire.

That is the test-quality lesson from `17_employee_walkthrough_test.sql` applied again: a passing negative test is not evidence until you know which guard fired.

The two positive cases matter as much as the three negative ones. Case 4 is precisely the row `request_finance_approval` writes today, so the constraint cannot have broken the existing finance path; case 5 uses an approval type with no typed column at all, proving the generic path canon requires — five of canon's seven approval types have no typed accessor — still works.

Recommendation to human: Set Status to Complete.

---

## Review Gate

- [x] Every change matches the Implementation Steps exactly.
- [x] No file outside the Scope list was modified or created.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] Supersedes / Depends On names no file requiring a Status change.
- [x] The repository is in a clean, releasable state.

---

## Notes

**Approval basis.** Owner directive 2026-08-21, which required REL-2 to be resolved before freeze and explicitly rejected deferring a known source-of-truth ambiguity on the grounds that there are currently zero divergent rows.

**How authority was decided.** From canon, not preference. `31_schema_draft.md` lists the `approval_requests` core fields and marks the optional ones explicitly — *"reviewed_by nullable"*, *"booking_item_id nullable"*, *"document_id nullable"* — while listing `related_entity_type` and `related_entity_id` **without** that marker. Canon also describes the table as a *"Generic approval workflow"* supporting seven approval types, of which only two (`finance_execution_approval` via booking item, and the document case) have a typed column at all. A representation that exists for two of seven types cannot be the general subject.

**Neither representation was removed, and that is deliberate.** Dropping the typed FKs would have been the tidier-looking change, but they are load-bearing: `review_finance_approval` joins on `booking_item_id`, and the column carries an index and a tenant-qualified foreign key. The defect was never that two columns existed — it was that they could disagree. Constraining them is the smaller and more honest correction.

**A second defect was closed on the way.** The subject columns were nullable in the implementation while canon lists them as core fields. An approval request is always *about* something; there is no such thing as an approval of nothing. That drift is now closed, and it is the kind of thing that becomes a data-cleanup exercise rather than a one-line `ALTER` once approvals exist.
