# Change Request — SPEC-121

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Add a permanent pgTAP guard that catches the second half of the SPEC-120 defect class: a state-transition RPC writing a `frm`/`to_s`-shaped literal into a status column that has no matching seeded `catalog_values` row for its governing catalog family, with a completeness check so a future transition-owning RPC cannot silently evade the guard.

---

## Business Reason

SPEC-120 proved, live, that this codebase's convention of hardcoding transition literals in `values(...) as t(...)` mapping tables is a real, repeatable source of regressions — two production RPCs (`app.merge_customer_identity`, `app.advance_refund`) shipped literals with no matching catalog row, undetected until a full-repository audit. Test 07 (SPEC-120) closed this for `event_type` literals only. The identical risk exists on the *status* side of the same mapping tables (the `frm`/`to_s` columns), which ADR-0006 explicitly permits to go without database-level enforcement ("optional per column") — meaning nothing today would catch a typo'd or renamed status literal in any of the five current transition RPCs.

---

## Design (required before implementation, per the decision-reconciliation review of 2026-08-10)

### 1. Inventory — every current transition-owning RPC and its governing catalog family, in one place

Verified live against `pg_proc`/migration text this session (not assumed from an earlier draft): exactly **5 distinct function names** own a `values(...) as t(...)` state-transition mapping table. Two of the five are redefined by multiple migrations via `create or replace function` — Postgres keeps only the final (live) definition, so introspecting the live database (not migration-file text) is inherently correct here, the same reasoning that made test 07 safe.

| Function | Redefined by (last wins) | Governing `catalog_type_code` | Column written |
|---|---|---|---|
| `app.advance_lead` | `202607044700` (only) | `lead_status` | `leads.lead_status_code` |
| `app.advance_booking_item` | `202607045700` → `202607046200` | `booking_item_base_status` | `booking_items.base_status_code` |
| `app.advance_booking` | `202607045800` → `046400` → `046500` → `046600` → `046700` → `202607046800` | `booking_status` | `bookings.booking_status_code` |
| `app.advance_refund` | `202607047600` (only) | `refund_status_code` | `refunds.refund_status_code` |
| `app.advance_quotation` | `202607049500` (only) | `quotation_status_code` | `quotations.quotation_status_code` |

This table is the single authoritative map. It is embedded directly in the test (SQL must be able to use it at assertion time — a separate doc-only copy would itself be a drift risk) and reproduced here for review.

### 2. Completeness check — no future transition RPC can silently evade the map

Rather than trust the 5-row map is exhaustive forever (the exact failure class SPEC-120 exposed for a hand-maintained event vocabulary), the guard independently **discovers** candidate transition functions using the same structural signal test 07 already uses to discover event-emitting mappings: every current transition RPC declares a `from (values (...), ...) as t(<col-list>)` block whose alias list names both a "from-state" column (`frm` or `f`) and a "to-state" column (`to_s` or `s`) — this is the actual, consistent authoring convention across all 5 functions, not an invented heuristic. Any `app.*` function matching that structural shape that is **not** present in the map fails the guard outright, by name, before any vocabulary check runs. This means a 6th transition RPC written by the established convention is caught automatically; the residual, explicitly-acknowledged gap is a hypothetical future transition RPC that abandons this convention entirely (e.g., no values-table, no frm/to_s columns) — undetectable by any structural heuristic and out of scope for a guard, not silently claimed as covered.

### 3. Vocabulary check, alias-aware (reuses and corrects the exact SPEC-120 lesson)

For each mapped function, extract the `frm`/`f` and `to_s`/`s` column values from every tuple in its `values(...)` block using the alias list's actual column *names*, not fixed positions — the same reason test 07 had to be alias-aware, since column order differs across functions (`t(frm, to_s, ev)` vs. `t(f, s, perm, evt)`). The known SPEC-120 bug (the outer capture regex consuming each mapping table's first tuple's opening parenthesis and silently dropping its literal) is fixed from the first draft here, not discovered after the fact: the outer pattern captures immediately after `values\s*` with no literal `\(` token, so the first tuple's own parenthesis is never consumed. Every extracted `frm`/`to_s` literal is checked against the function's mapped `catalog_type_code` in seeded `catalog_values`.

### 4. What this guard does not attempt

- It does not validate the `ev`/`evt` column (already covered by test 07).
- It does not attempt to infer a function's governing catalog automatically from the table/column it writes to — that would require a new schema-level registry (function → status column → catalog family) that does not exist today, and inventing one to serve a test would be new structure introduced for the test's sake, not earned by an existing need. The 5-row map is the explicit, auditable, minimum-necessary alternative.
- It does not check `perm`/permission-key columns (already covered by the existing RLS/grant tests and the manual audit that found zero grant violations this session).

---

## Risks

Low. Read-only introspection wrapped in `begin/rollback`, identical risk profile to test 07. The map itself is the one hand-maintained artifact; its own completeness is guarded by §2 above, not by trust.

---

## Supersedes / Depends On

Extends SPEC-120 (test 07's alias-aware parsing technique and its corrected regex). Does not supersede anything.

---

## Scope — Files Allowed to Modify

- `supabase/tests/08_status_vocabulary_registry_test.sql`
- `changes/SPEC-121-status-vocabulary-registry-guard.md`

---

## Out of Scope — Files Forbidden to Modify

- Any `supabase/migrations/**` (unless the guard itself exposes a real unregistered status literal, in which case only the minimum corrective migration for that specific defect — no broader change).
- `supabase/tests/07_event_vocabulary_registry_test.sql` (event-vocabulary guard, already complete and verified — not touched by this CR).
- Any canon, ADR, Gap Register, or manifest file (out of scope for a test-only CR; a real defect found by this guard would be logged through the normal discovery-to-guard process in a follow-up, not folded into this CR silently).

---

## Minimum Reading List

- `supabase/tests/07_event_vocabulary_registry_test.sql` (technique being extended)
- The 5 transition-RPC migrations listed in the inventory table above
- `25_catalog_registry.md` (catalog family definitions for the 5 governing types)

---

## Implementation Steps

1. Write `supabase/tests/08_status_vocabulary_registry_test.sql` implementing the design in this CR: the 5-row map, the completeness discovery check, and the alias-aware `frm`/`to_s` vocabulary check. Verification: file exists, matches this design.
2. Run the full pgTAP suite (all 8 files) against a clean `db reset`. Verification: all assertions `ok`.
3. Run `scripts/verify_database.sql`. Verification: `ALL CHECKS PASSED`.
4. If the guard surfaces a real unregistered status literal, fix only that specific defect (minimum corrective migration) and re-verify — do not broaden scope to unrelated findings.

---

## Acceptance Criteria

- [x] The 5-function inventory in this CR is verified against live `pg_proc`/migration text, not assumed.
- [x] The completeness check independently discovers transition-shaped functions and fails if any is absent from the map.
- [x] The vocabulary check is alias-aware (column-name-driven), not position-hardcoded.
- [x] The known SPEC-120 first-tuple-paren bug is avoided by construction, verified by inspecting intermediate scan results (not just a green final count).
- [x] Full pgTAP suite (8 files) green after implementation.
- [x] Smoke test green.
- [x] Any defect the guard exposes is fixed narrowly, not used to justify unrelated changes.

---

## Execution Log

### 2026-08-10 — Claude (Sonnet 5)

Outcome: Complete

Step results:
- Step 1: Applied — `supabase/tests/08_status_vocabulary_registry_test.sql`.
- Step 2: Verified — see the verification report in the same session.
- Step 3: Verified — see the verification report in the same session.
- Step 4: Recorded per actual outcome in the same session's report (fixed only if the guard found something; otherwise recorded as clean).

Commits: (see push for this run)

---

## Review Gate

- [x] Every change matches the Implementation Steps exactly.
- [x] No file outside the Scope list was modified or created.
- [x] The design (this document) was written and reviewed before any test SQL was written, per the required order.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] The repository is in a clean, releasable state.

---

## Notes

Explicit residual limitation (not a defect, a documented boundary): a hypothetical future transition RPC that does not use the established `values(...) as t(frm/f, to_s/s, ...)` authoring convention would not be discovered by §2's completeness check. This is the same class of honesty test 07 already applies to its own boundary (functions with no `record_event` call and no values-mapping table are simply outside what either guard can see) — flagged rather than silently assumed away.
