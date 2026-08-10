# Change Request — SPEC-118

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Widen every monetary column from `numeric(14,2)` to `numeric(19,4)` so 3-decimal currencies (KWD/BHD/OMR/JOD) are stored without truncation (ARB finding DC-1 / R7).

---

## Business Reason

`numeric(14,2)` truncates the minor unit of 3-decimal ISO 4217 currencies, silently corrupting money for GCC currencies in ORVION's scope. DC-1 is the single Critical correctness finding (RK-01); the fix is cheapest now while tables are empty. `numeric(19,4)` covers ISO 4217's maximum minor unit (4) with integer headroom.

---

## Risks

Low. Widening `numeric` is loss-free; no data exists yet; existing CHECK constraints (non-negative, debit-xor-credit) remain valid and are preserved by `ALTER COLUMN TYPE`; no RPC hard-codes precision (verified); no views exist. The only behavioral change is the removal of truncation.

---

## Supersedes / Depends On

None. Closes gap DC-1 / R7 (RK-01).

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607048600_dc1_widen_money_precision.sql`
- `supabase/tests/03_money_currency_precision_test.sql`
- `_ORVION_CANONICAL/30_database_conventions.md`
- `_ORVION_CANONICAL/31_schema_draft.md`
- `_ORVION_CANONICAL/manifest.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_RISK_REGISTER.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `changes/SPEC-118-dc1-money-precision.md`

---

## Out of Scope — Files Forbidden to Modify

- any other `supabase/migrations/**` (terminal migrations are never edited)
- any `reports/history/**` (immutable)
- any other `changes/SPEC-*.md`

---

## Minimum Reading List

- `reports/master/MASTER_GAP_REGISTER.md` (DC-1 / R7 row)
- `_ORVION_CANONICAL/30_database_conventions.md` (Money Standard)
- `supabase/tests/03_money_currency_precision_test.sql`

---

## Implementation Steps

1. Add migration `202607048600_dc1_widen_money_precision.sql` altering the 21 monetary columns to `numeric(19,4)` (excluding `quotation_items.quantity` and `exchange_rates.exchange_rate`). Verification: file exists and `npx supabase db reset` applies cleanly.
2. Convert `supabase/tests/03_money_currency_precision_test.sql` from a `todo` block to a hard assertion. Verification: file contains no `todo_start`.
3. Update the Money Standard in `30_database_conventions.md` and its reference in `31_schema_draft.md` to `numeric(19,4)`. Verification: neither file's Money Standard states `numeric(14, 2)`.
4. Mark DC-1/R7 (RK-01) implemented in the three Master registers. Verification: gap register DC-1 row shows implemented + SPEC-118.
5. Sync `manifest.md` `Last Completed`. Verification: manifest names SPEC-118.

---

## Acceptance Criteria

- [x] All 21 monetary columns are `numeric(19,4)` after `db reset` (verified by query).
- [x] pgTAP test 03 passes as a hard gate (no `todo`).
- [x] Full smoke test prints `ALL CHECKS PASSED`.
- [x] A 3-decimal value (e.g. 1.234) round-trips without truncation.
- [x] Money Standard in canon reads `numeric(19,4)`.

---

## Execution Log

### 2026-07-13 — Claude (Opus 4.8)

Outcome: Complete

Step results:
- Step 1: Applied — migration `202607048600` widens 21 columns; `db reset` clean.
- Step 2: Applied — test 03 is now a hard gate.
- Step 3: Applied — canon 30/31 Money Standard = `numeric(19,4)`.
- Step 4: Applied — DC-1/R7/RK-01 marked implemented.
- Step 5: Applied — manifest `Last Completed` = SPEC-118.

Commits: (see push for this run)

---

## Verification Notes

### 2026-07-13 — Claude (Opus 4.8)

Verdict: Confirmed Complete

Findings: Re-verified against the live database after `db reset`: all 21 columns report `numeric(19,4)`; `quotation_items.quantity` unchanged; behavioral test inserted `1.234` into a money column and read it back untruncated; all 6 pgTAP tests green including test 03 as a hard gate; full smoke test `ALL CHECKS PASSED (71 tables)`. Canon Money Standard reads `numeric(19,4)`. No out-of-scope file modified.

Recommendation to human: Set Status to Complete.

---

## Review Gate

- [x] Every change matches the Implementation Steps exactly.
- [x] No file outside the Scope list was modified or created.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] Supersedes / Depends On names no file requiring a status change.
- [x] The repository is in a clean, releasable state.

---

## Notes

DC-1 is the Batch-0 foundation-lock finding; landing it before Phase 8 ensures `offline_conversions.conversion_value` is built on the correct money type.
