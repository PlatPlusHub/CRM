# ORVION — SPEC-154: The Employee Could Not Do Their Job

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-27
Author: Claude Opus 5
Scope: Business-intent validation of the role model against canon 28, the resulting employee-role
alignment (`202607053500`), and a booking defect discovered while proving the workflow
(`202607053600`).

Predecessor: `wp-02-class-a-events-2026-08-27.md`.

---

## STATUS — **EARNED → CLOSED**

## THE HEADLINE

The owner's proposed business intent — *an ordinary employee should be able to perform the normal
sales work for their assigned customers* — was put to canon rather than assumed, and **canon
confirmed it outright**. Canon 28's Employee column marks `CREATE_QUOTATION`, `CREATE_BOOKING`,
`CREATE_BOOKING_ITEM` and fourteen others `Yes` or `Assigned only`. The seed granted them to every
role down to `senior_employee` and stopped.

So this was an **ENGINEERING DEFECT**, not a business decision — and one whose class this repository
had already met: canon 28's own amendments §3 records *"the seed gave the permission to `owner` and
`ceo` only"* for `VIEW_BRANCH_DATA`.

Before this migration an ordinary employee could not quote a customer, close a lead, complete a task,
resolve a complaint, send a message, upload a document, or create a booking. **Every capability this
programme has built — creation events, 360 timelines, the subscription gate, financial privacy —
existed to support a workflow the front-line role could not execute.**

## DISCOVERED

**D1 — 17 canon-mandated permissions stopped at `senior_employee`.** Verified by joining
`permissions` × `role_permissions` × `roles` and comparing against canon 28 row by row. All 17
permissions *existed*; `employee` simply was not granted them.

**D2 — `app.create_booking` was broken on the direct path for EVERY role.** Found only because
SPEC-154 finally let an employee reach the booking step. A walk-in customer booked directly — no
lead, no quotation — raised:

```
ERROR:  record "v_quote" is not assigned yet     -- SQLSTATE 55000
```

An entirely ordinary travel-agency action, impossible for owner, CEO and employee alike, latent
because no test exercised that path.

*Root cause is a plpgsql evaluation-order trap, worth remembering:* plpgsql rewrites a statement into
a query and binds every referenced variable as a **parameter**, so
`case when p_quotation_id is not null then v_quote.customer_id end` resolves `v_quote.customer_id`
*before* the CASE can short-circuit. Reading a field off an unassigned RECORD raises 55000. The guard
reads as if it protects the reference; it cannot. **The same trap sat in a second place**
(`if p_quotation_id is not null and v_customer <> v_quote.customer_id` — an `IF a and b` is likewise
one SQL expression), still latent because the first raised earlier. Fixing only the reported one
would have moved the error rather than removed it.

**D3 — Canon can mandate a permission the enforcement layer cannot scope.** `ENTER_COST` /
`ENTER_SELLING_PRICE` are marked "Assigned only" for Employee, but
`app.guard_booking_item_financials` calls `app.authorize('ENTER_COST')` — role-based only, never
asking whether *this item* belongs to the caller. Granting would have let an employee write cost on a
**colleague's** item, exceeding canon rather than implementing it.

`29_financial_write_authority_test.sql` assertion 6 caught this within minutes of the first grant
attempt. **The guard was not weakened to admit the grant** — the permission was withheld instead, and
the scope gap recorded as SPEC-154-A. That test's header had also encoded the seed's under-grant as
if it were the rule (*"employee — holds none of the finance permissions"*), the same pattern WP-03
found in `30_plan_gating_test.sql`; it was left correct-as-written because withholding the permission
keeps its assertion true.

## FIXED

* **`202607053500`** — 15 permissions granted to `employee` (13 → **28**).
* **`202607053600`** — `create_booking` direct path repaired via a scalar `v_quote_customer`.

## VERIFIED

| Check | Result |
|---|---|
| New guard `39_employee_day_one_workflow_test.sql` | **16/16** |
| Suite | **39 files / 392 assertions / 0 failures** |
| Smoke | `ALL CHECKS PASSED` |
| Repository guard | CLEAN |
| Database parity | `CLEAN (local proven; primary proven)` |
| repo = local = Primary | **125 migrations**, `c577ad39945bf58dfb8b21b5bdea894f` |
| Primary live | `employee` = 28 permissions · `create_booking` carries the fix · 109 `app` functions |

**The day-one journey, executed end to end by a real authenticated employee through real RPCs:**
register walk-in customer → open lead → schedule follow-up → **quote** → price → send → **book** →
add service line. Steps 4 and 7 were impossible before.

**The grant is not a promotion** — each denial follows eight successful business actions by the same
actor in the same session, so no denial can pass on an empty fixture: still cannot write a cost,
approve finance, set the exchange rate, or promote themselves to owner. Branch isolation holds, with
a positive control proving their own booking *is* visible.

## NOT FIXED (deliberate, recorded)

* **SPEC-154-A** — financial guard is not scope-aware, so `ENTER_COST` / `ENTER_SELLING_PRICE` stay
  withheld despite canon mandating them.
* **SPEC-154-B** — `VIEW_FINANCIAL_DOCUMENTS` is a binary tenant-wide gate and cannot express canon's
  "assigned related only". Granting it would regress SPEC-139.
* `ASSIGN_SUPPLIER` — canon marks Employee "Optional"; optional is not mandated.
* WP-03's broad `documents` subscription-gate exemption → WP-04.
* Missing `payment_proof` document type.
* 58 never-emitted events, all Class B/C (no producer exists).

## BLOCKED (unchanged, commercial)

**BLOCKED-1** trial plan tier + duration at provisioning. **BLOCKED-2** `MANAGE_SUBSCRIPTION`
"Limited" for Owner/CEO.

## RISK INTRODUCED — and contained

Granting 15 permissions to the most numerous role is the widest blast radius of this programme so
far. Contained by: canon as the sole source for *which* permissions (nothing invented); the existing
RLS scope model for *where*; the full 39-file suite as the regression net; and an explicit
not-a-promotion block in the new test. The one over-grant attempted (`ENTER_COST`) was caught by an
existing guard and withdrawn.

## CURRENT STATE

* **125 migrations**, latest `202607053600`, fingerprint `c577ad39945bf58dfb8b21b5bdea894f` on
  repository, local and Primary.
* 72 tables · 109 `app` functions · 116 policies · 71 permissions · `employee` = 28 permissions.
  Primary holds zero business rows.
* Suite 39 files / 392 assertions / 0 failures. Smoke passes. Both guards CLEAN.
* Git: `main`, tree clean, pushed.

## NEXT STEP

**SPEC-154-A — make `app.guard_booking_item_financials` scope-aware**, then grant `ENTER_COST` /
`ENTER_SELLING_PRICE` per canon. It is the direct continuation of this package, it closes the last
two canon-vs-live role gaps, and it is the remaining reason an employee cannot complete the *pricing*
half of their own booking.

After that, on evidence: **WP-04 documents/storage** (zero buckets, zero storage policies, plus
narrowing the WP-03 `documents` exemption and resolving `payment_proof`) — the largest remaining
"schema object exists but the capability does not" gap.
