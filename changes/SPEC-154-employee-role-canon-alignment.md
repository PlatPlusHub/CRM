# Change Request — SPEC-154 (Employee Role Canon Alignment)

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

**EARNED → CLOSED (2026-08-27, migrations `202607053500` + `202607053600`).** Suite 39 files / 392
assertions / 0 failures; repo = local = Primary = `c577ad39945bf58dfb8b21b5bdea894f` at 125.
Evidence: `reports/history/spec-154-employee-role-canon-alignment-2026-08-27.md`.

---

## Objective

Make the ordinary `employee` role able to perform the job canon 28 says it performs.

## The finding — an ENGINEERING DEFECT, not a business decision

Live introspection against canon 28 found **seventeen** permissions whose Employee column canon marks
`Yes` or `Assigned only`, granted to every role down to `senior_employee` and then stopped. The seed
under-granted; canon did not change.

Canon is explicit:

```
CREATE_QUOTATION    | Yes | Yes | Yes | Yes | Yes | Assigned only | No  | assigned/department
CREATE_BOOKING      | Yes | Yes | Yes | Yes | No  | Yes | Assigned only | No | branch/department
CREATE_BOOKING_ITEM | Yes | Yes | Yes | Yes | No  | Yes | Assigned only | No | branch/department
```

The classification is settled by precedent as well as by the text: canon 28's own *"Amendments
ratified with this model"* §3 records the identical shape — *"the seed gave the permission to `owner`
and `ceo` only"* — for `VIEW_BRANCH_DATA`. A seed under-grant is a known, previously-corrected defect
class in this repository.

**Business consequence.** An ordinary employee could not quote a customer, close a lead, complete a
task, resolve a complaint, send a message, or create a booking. Every capability this programme has
built — creation events, 360 timelines, the subscription gate, financial privacy — supports a
workflow the front-line role could not execute at all.

## Granted (15)

`CLOSE_LEAD` · `COMPLETE_TASK` · `RESOLVE_COMPLAINT` · `RESOLVE_SERVICE_REQUEST` ·
`CREATE_QUOTATION` · `SEND_QUOTATION` · `ACCEPT_QUOTATION` · `SEND_MESSAGE` · `CLOSE_CONVERSATION` ·
`CREATE_BOOKING` · `CREATE_BOOKING_ITEM` · `UPDATE_BOOKING_ITEM_STATUS` · `UPLOAD_DOCUMENT` ·
`CREATE_DOCUMENT_VERSION` · `VIEW_TRAVEL_DOCUMENTS`

`employee`: 13 → **28** permissions.

**Scope is not widened.** `app.has_permission` answers *does this role hold this capability*; WHERE it
may be exercised is enforced separately by the SPEC-137 RLS scope model (`owner_user_id =
app.current_user_id()` plus branch/department predicates). Canon's "Assigned only" stays enforced by
the policies. Proven: after the grant, the employee still cannot see another branch's booking.

## Withheld — three canon entries deliberately NOT granted

| Entry | Canon says | Why withheld |
|---|---|---|
| `ENTER_COST`, `ENTER_SELLING_PRICE` | Employee "Assigned only" | **The enforcement layer cannot express the scope.** `app.guard_booking_item_financials` calls `app.authorize('ENTER_COST')` — role-based only; it never asks whether *this item* is the caller's. Granting would let an employee write cost on a **colleague's** item, exceeding canon rather than implementing it. `29_financial_write_authority_test.sql` assertion 6 proved this within minutes of the grant. Withholding is the conservative reading; weakening the guard would have been the wrong direction. |
| `VIEW_FINANCIAL_DOCUMENTS` | Employee "Assigned related only" | The live permission carries **no scope argument** — it is a binary tenant-wide finance gate inside the `payments`, `payment_allocations` and `booking_items` policies. Granting it would hand every employee tenant-wide financial visibility and regress SPEC-139. Canon's scoped intent cannot be expressed by today's binary permission. |
| `ASSIGN_SUPPLIER` | Employee "Optional" | Optional is not mandated. Granting on an optional marking would be inventing business policy. |

## Defect discovered while proving the workflow

**`app.create_booking` could not create a booking on the direct path at all** — walk-in customer, no
lead, no quotation:

```
ERROR:  record "v_quote" is not assigned yet     -- SQLSTATE 55000
```

Broken for **every role**, not only employees, and latent because no test exercised that path. Root
cause is a plpgsql evaluation-order trap, not a logic error: plpgsql rewrites the statement into a
query and binds every referenced variable as a parameter, so `v_quote.customer_id` resolves *before*
the `case when p_quotation_id is not null` can short-circuit. The same trap sat in a second, still
latent place (`if p_quotation_id is not null and v_customer <> v_quote.customer_id` — an `IF a and b`
is likewise one SQL expression). Both fixed by carrying the value in a scalar `v_quote_customer`,
which is simply NULL when unset. Fixing only the reported one would have moved the error, not removed
it. Migration `202607053600`.

## Acceptance criteria — all satisfied

1. Employee performs the full journey through real RPCs: customer → lead → task → **quotation** →
   price → send → **booking** → booking item. ✅ (`39_employee_day_one_workflow_test.sql` 1–8)
2. The work is genuinely recorded, not merely permitted — `customer_created` emitted, Customer 360
   begins at creation. ✅ (9–10)
3. The grant is not a promotion: still denied cost writes, finance approval, exchange rates, and
   self-promotion to owner. ✅ (11–14)
4. Branch isolation survives: the Alexandria colleague's booking stays invisible, **with a positive
   control** proving their own booking is visible. ✅ (15–16)
5. Full suite + smoke green; both guards CLEAN; repo = local = Primary by fingerprint. ✅

## Open items this CR creates

* **SPEC-154-A — make the financial guard scope-aware** so `ENTER_COST` / `ENTER_SELLING_PRICE` can be
  granted per canon without over-granting to colleagues' items.
* **SPEC-154-B — `VIEW_FINANCIAL_DOCUMENTS` cannot express "assigned related only."** Canon-vs-
  implementation contradiction; needs either a scoped permission or an accessor like
  `app.item_financials`.

Neither blocks anything; both are recorded rather than silently dropped.
