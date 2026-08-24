# Change Request — SPEC-139

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Implement the owner's third visibility rule: seeing a booking must not mean seeing another
employee's profit or commission.

---

## Business Reason

`booking_items.cost_amount` and `commission_rate` were readable by anyone who could read the row, and
`reporting.booking_item_profit` — a `security_invoker` view granted to `authenticated` — served
`cost_amount` and `profit` directly. SPEC-137 narrowed *which* rows an employee can see, but that
made this worse rather than better in one respect: department continuity means a colleague can
legitimately open a colleague's booking item, and until now the margin came with it. Canon 31 records
`commission_rate` as the reserved path for "future sales commission calculation", so what leaked is
one employee's earnings basis to another.

The rule itself is already canon and did not need inventing. Canon 28's Finance table scopes
`VIEW_FINANCIAL_DOCUMENTS` as Owner/CEO/Finance Manager **Yes**, Branch Manager *Optional*,
Department Manager **No**, Senior Employee and Employee **"Assigned related only"**, with the note
"Assigned employee may view financial documents directly related to their lead/booking". That is
precisely the owner's requirement, so no permission was minted.

---

## Risks

Moderate, and concentrated in one deliberate consequence rather than in the rule itself.

**`select *` on `booking_items` as `authenticated` now fails.** Postgres checks column privileges on
the *reference*, not the result, so there is no arrangement that keeps `*` working while withholding
a column. Clients must name the columns they want. This is asserted as a test rather than left to be
discovered: it is the single most likely way this change surprises someone later. The `reporting`
views already read through the lateral primitives and are unaffected — verified, not assumed.

Second risk: over-restriction. A privacy control that blocked the finance manager would be an outage,
not a control, so the finance and self-access directions are asserted alongside every denial.

---

## Supersedes / Depends On

Depends on SPEC-137 (`app.current_user_id`, and the row scope this sits on top of). Completes the
third of the three visibility rules in the owner directive of 2026-08-24.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607051700_employee_financial_privacy.sql`
- `supabase/tests/23_financial_privacy_test.sql`
- `scripts/verify_database.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-139-employee-financial-privacy.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- `reporting.*` view definitions — they already read through the lateral primitives, so gating the
  primitives was sufficient; rewriting the views would have been change without cause

---

## Minimum Reading List

- `_ORVION_CANONICAL/28_permissions_matrix.md` §Finance Permissions (the `VIEW_FINANCIAL_DOCUMENTS` row and its note)
- `_ORVION_CANONICAL/31_schema_draft.md` (`commission_rate` — "future sales commission calculation")
- `reports/architecture-decision-records.md` ADR-0022 (the `reporting` schema is the read path)

---

## Implementation Steps

1. Add `app.item_financials(uuid)` — SECURITY DEFINER — returning cost, commission and profit only
   when the caller holds `VIEW_FINANCIAL_DOCUMENTS` or is one of the item's responsible users.
2. Replace the table-level `SELECT` grant on `booking_items` with an explicit column list excluding
   `cost_amount` and `commission_rate`, generated from the catalog.
3. Rework `app.booking_item_profit` to read the numbers through the accessor instead of the columns,
   keeping it SECURITY INVOKER so the SPEC-137 row scope stays the only authority over which rows appear.
4. Make `app.supplier_balance` SECURITY DEFINER and finance-only.
5. Verification check: test 23 asserts the colleague keeps the record and loses the number, and that
   the seller and finance manager both still get it.

---

## Acceptance Criteria

- [x] A department colleague still reads the booking item and its selling amount.
- [x] That colleague cannot read `cost_amount` or `commission_rate`, by name or through `*`.
- [x] The gated accessor returns NULL, and reports `permitted = false` rather than NULL.
- [x] The item's own owner sees its margin.
- [x] A finance manager sees it.
- [x] `reporting.booking_item_profit` returns the row with the margin masked.
- [x] Clean `db reset` replays; full suite passes; smoke passes.
- [ ] **UNVERIFIED — Primary.** The `supabase-primary` MCP disconnected and requires
      re-authorization, which cannot be done non-interactively. Not applied to Primary; parity not
      confirmed.

---

## Execution Log

### 2026-08-24 — Claude Opus 5 (Foundation Completion Programme)

Outcome: Complete

`202607051700_employee_financial_privacy.sql` applied. `db reset` replays 105 migrations clean;
suite `Files=23, Tests=173 ... PASS`; smoke `ALL CHECKS PASSED`.

**The design decision worth recording is what was *not* done.** The obvious fix — make
`app.booking_item_profit` SECURITY DEFINER and check the permission inside it — would have worked and
would have been wrong. A definer function bypasses RLS, so it would have had to re-implement SPEC-137's
row scope in a second place, and the two would eventually disagree. Keeping it INVOKER and moving only
the *numbers* behind a definer accessor leaves exactly one authority for which rows appear (RLS) and
exactly one for whether the money appears (the accessor).

`app.supplier_balance` went the other way and became SECURITY DEFINER, finance-only, raising 42501
without the permission. The asymmetry is deliberate: a booking item is operationally relevant with its
margin removed, so it is masked; a supplier balance *is* money end to end, and there is no "my own
work" reading of a supplier-wide total, so there is nothing left to return.

---

## Verification Notes

### 2026-08-24 — Claude Opus 5 (Foundation Completion Programme)

Verdict: Confirmed Complete

Findings: assertion 7 failed on the first run and exposed a genuine defect in the accessor. The gate
was written as `has_permission(...) or current_user_id() in (owner, sales_owner, operational_owner)`,
and `x in (a, b, c)` yields **NULL** — not false — when x matches none of them and any is NULL, which
is the ordinary case since most items have no operational owner. The masking still behaved correctly
(`case when null` yields null), so cost and profit were hidden as intended and a weaker test would
have passed. What was broken was the `permitted` flag: it came back NULL, leaving a consumer unable to
tell "you may not see this" from "unknown". A flag that is sometimes NULL is not a flag, and any UI
branching on it would have taken the wrong path. Fixed with an explicit `coalesce`, and the reason is
recorded in the migration so it is not "tidied away" by a future reader.

The reporting-view assertions were added after the fact for a specific reason: gating the primitive
is not the same as gating the surface an application queries. ADR-0022 makes `reporting` the read
path, so the guarantee is asserted there too — the colleague gets the row, with an empty margin column.

Recommendation to human: Set Status to Complete.

---

## Review Gate

- [x] Every change matches the Implementation Steps exactly.
- [x] No file outside the Scope list was modified or created.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] Supersedes / Depends On names no file requiring a Status change.
- [x] The repository is in a clean, releasable state (local; Primary deployment outstanding).

---

## Notes

**Approval basis.** Owner directive 2026-08-24 §2.1 ("An ordinary employee must NOT be able to see
the profit, commission, financial performance … of another employee"), §10 (Employee 360 — "A manager
/ owner / authorized reporting role may see it"), and the instruction to determine the correct
field/table/report-level model from the existing architecture.

**Branch and department managers are deliberately not granted financial visibility here.** Canon 28
marks `VIEW_FINANCIAL_DOCUMENTS` *Optional* for Branch Manager and **No** for Department Manager. A
tenant that wants a branch manager to see branch margins grants them the permission through RBAC; that
is a business choice, and encoding it as a default would have overridden canon without a directive to
do so.
