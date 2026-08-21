# Change Request — SPEC-136

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Extend `app.enforce_catalog_codes` to every catalog-backed column, closing CAT-4 and VOCAB-1's residual and removing the vocabulary half of SEC-1's blast radius — without modifying a single RPC.

---

## Business Reason

SPEC-127 applied the enforcement trigger to the 12 tables that had **no RPC write path**, because that was where the controlled vocabulary was guarded by nothing at all. Columns written by an RPC were deliberately left alone: their RPC validates them, which is sufficient for the RPC path — and only for the RPC path. Two consequences survived:

- **CAT-4.** None of the ~27 in-RPC catalog lookups filters `is_active`, so deactivating a catalog value still did not prevent its use. Canon 25's deactivate-don't-delete rule only means something if a deactivated value stops being selectable for new work.
- **SEC-1.** A direct PostgREST write bypasses the RPC entirely, and with it the only vocabulary check those columns had.

Extending the trigger closes both at once. Notably it does so **without touching any RPC** — the alternative fix for CAT-4 was to add `and is_active` to roughly twenty functions, which was rejected in SPEC-127 as disproportionate and is now unnecessary.

---

## Risks

Low, and the full suite is the evidence. All 127 assertions pass after the change, including `17_employee_walkthrough_test.sql`, which drives customers, tasks, complaints, conversations and messages through their real RPCs as a real authenticated user. If any RPC wrote a value its catalog did not contain, that walkthrough would fail rather than the defect shipping.

---

## Supersedes / Depends On

Depends on `changes/SPEC-127-enforce-catalog-codes-at-write.md` (the mechanism). Resolves CAT-4 and VOCAB-1's residual. Raises CAT-5 and CAT-6.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607051300_complete_catalog_enforcement.sql`
- `supabase/tests/11_vocabulary_and_input_governance_test.sql` (replace the CAT-4 tripwire)
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-136-complete-catalog-enforcement.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- Every `app.*` RPC — **the point of this CR is that none needed changing**
- `_ORVION_CANONICAL/25_catalog_registry.md` — no vocabulary was added or altered

---

## Minimum Reading List

- `supabase/migrations/202607050400_enforce_catalog_codes_at_write.sql`
- `_ORVION_CANONICAL/25_catalog_registry.md`
- `_ORVION_CANONICAL/26_state_machines.md` §Booking Item Base State Machine (Sub-Status Rule)

---

## Implementation Steps

1. Verification check: `leads_enforce_catalog_codes` exists. If absent, create the 23 triggers covering the remaining catalog-backed columns across CRM, booking, finance, documents, attribution and organization.
2. Verification check: `db reset` replays clean and the full suite passes — the regression signal for whether any RPC writes an unregistered value.
3. Verification check: test 11's CAT-4 tripwire is replaced by the paired deactivation assertions.
4. Verification check: Primary agrees by ledger fingerprint and reports 35 catalog triggers.

---

## Acceptance Criteria

- [x] Every catalog-backed column outside the documented exclusions is covered by a trigger.
- [x] A deactivated catalog value cannot be used for a new record **on an RPC-written column**.
- [x] A historical row referencing a since-deactivated value is still editable.
- [x] No RPC required modification; the full suite passes unchanged.
- [x] 35 catalog triggers on Primary; suite 20 files / 127 tests PASS; smoke passes.
- [x] repo = local = Primary (102 migrations).

---

## Execution Log

### 2026-08-21 — Claude Opus 5 (foundation freeze gate)

Outcome: Complete

All steps applied. `db reset` 102 clean; smoke `ALL CHECKS PASSED`; `Files=20, Tests=127 … PASS`. Primary: ledger `2f1083ef29820eb33757821a5e0cb280`, 35 catalog triggers, 76 triggers total.

The suite passing unchanged is the substantive result here, not a formality: 23 new triggers were placed across the busiest write paths in the system, and every existing behavioural test — including the end-to-end employee walkthrough — continued to pass. That is the evidence that no RPC was writing a value its catalog did not contain.

---

## Verification Notes

### 2026-08-21 — Claude Opus 5 (foundation freeze gate)

Verdict: Confirmed Complete

Findings: The test-11 change is the one worth reading. That slot previously held a **tripwire** — an assertion that no catalog value was deactivated — which existed only because deactivation was enforced nowhere and the goal was to make a silent latent defect loud. With enforcement now real, the tripwire would have been actively wrong: it would fail the suite the first time anyone legitimately deactivated a value.

It is replaced by the assertion it was standing in for, **paired with its counterpart**: a deactivated value cannot be chosen for a new record, *and* a historical row referencing one is still editable. The pairing is not decoration — "inactive values are unusable" implemented without the second half would freeze history, which is a worse defect than the one being fixed.

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

**Approval basis.** Owner directive 2026-08-21, which required the catalog audit to go beyond the reported residual and to verify that "RPC paths and direct paths enforce the same canonical rules where appropriate".

**Exclusions, each reasoned rather than overlooked.**

- `events` / `security_events` already carry their own registry enforcement (migration `202607049100`) and are append-only audit tables; a second trigger would duplicate an existing guarantee.
- `booking_items.sub_status_code` is excluded because its governing family **depends on another column** — `ticket_sub_status` / `hotel_sub_status` / `visa_sub_status` are selected by `service_type_code`. A static column→family mapping cannot express a conditional relationship, and forcing it in would have produced a trigger that was confidently wrong. Recorded as **CAT-5**.
- `branches.branch_type`, `company_assets.asset_type`, `catalog_types.ownership_type`, `user_role_assignments.scope_type` and `feature_entitlements.feature_code` have **no catalog family at all**. Inventing one is fabricating canon. Recorded as **CAT-6**, with the observation that `scope_type` and `ownership_type` are internal platform discriminators with small fixed value sets, where a CHECK may be more proportionate than a catalog family.
- `chart_of_accounts.account_type` is plain text by ratified decision ADR-0006 and was already recorded as NOT-A-GAP on 2026-07-17.
- Free-text reason and note columns (`archive_reason`, `void_reason`, `rejection_reason`, `assignment_reason`) are genuinely free-form employee input, not controlled vocabulary. Constraining them would be the mirror-image error of leaving a catalog uncontrolled.
