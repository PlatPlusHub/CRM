# ORVION — SPEC-154-A: Scope-Aware Financial Guard

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-27
Author: Claude Opus 5
Scope: Making canon 28's `assigned` scope on `ENTER_COST` / `ENTER_SELLING_PRICE` enforceable, then
granting the two permissions SPEC-154 had to withhold (migration `202607053700`).

Predecessor: `spec-154-employee-role-canon-alignment-2026-08-27.md`.

---

## STATUS — **EARNED → CLOSED**

## THE GAP THIS CLOSES

SPEC-154 could not grant `ENTER_COST` / `ENTER_SELLING_PRICE` even though canon 28 mandates them for
Employee: `app.guard_booking_item_financials` asked only *does this ROLE hold ENTER_COST* and never
*is this item the caller's*. Granting against a role-only guard would have let an employee price a
**colleague's** booking item — exceeding canon rather than implementing it. Order mattered:
**fix enforcement first, grant second.**

## HOW "ASSIGNED" WAS DETERMINED — discovered, not invented

`booking_items` carries three ownership columns (`owner_user_id`, `sales_owner_user_id`,
`operational_owner_user_id`), and the table's own SPEC-137 RLS policy already defines "this row is
mine" as the caller matching **any** of the three. That is ORVION's existing assignment concept, so
the guard reuses it verbatim. A second, narrower definition would have created two competing answers
to one question.

## WHY THE RULE APPLIES TO EVERY ROLE, not just `employee`

Canon 28 says Employee "Assigned only" but Senior Employee "Yes" — yet **`employee` and
`senior_employee` hold an identical scope-permission set** (both have `VIEW_DEPARTMENT_QUEUE` and
`VIEW_DEPARTMENT_RECORDS`; neither has `VIEW_BRANCH_DATA`). No permission-based discriminator exists,
so a role-name check would have been the only alternative — which canon 28 forbids, the model being
permission-driven.

Canon settles it from the other direction: **the Scope column of both permission rows reads
`assigned`** for the whole row, not per-role. Assignment is the row-level rule; the per-role wording
is emphasis. Encoding it uniformly needs no role names at all.

The single exemption is `app.has_tenant_wide_read()` (`VIEW_ALL_BRANCHES` — owner and CEO only),
tenant-wide everywhere else in the model. Without it the tenant owner could not price an item they do
not personally own, which no reading of canon supports.

## WHAT WAS DELIBERATELY NOT CHANGED

The migration only **adds** a condition; every existing authority check is untouched:

* `EDIT_LOCKED_COST` still governs a cost after the lock — **no** assignment requirement, because
  canon scope is `tenant` and finance edits precisely the items that are *not* theirs.
* `APPROVE_FINANCE` still governs the lock itself and the approval status (canon scope `tenant`).
* The zero-value reasoning is intact: `cost_amount`/`selling_amount` are NOT NULL DEFAULT 0, so only
  a NON-ZERO value counts as entering one.
* The `auth.uid() is null` service_role/migration exemption is intact (canon 35 principle 6).

A caller who could not write before still cannot. **The guard was strengthened, never weakened.**

## VERIFIED

| Check | Result |
|---|---|
| New guard `40_financial_scope_test.sql` | **15/15** |
| Suite | **40 files / 407 assertions / 0 failures** |
| Smoke | `ALL CHECKS PASSED` |
| Repository guard | CLEAN |
| Database parity | `CLEAN (local proven; primary proven)` |
| repo = local = Primary | **126 migrations**, `a07d00fbb02a7f5ae39423f5380adaaf` |
| Primary live | `employee` = **30** permissions · guard scope-aware · `cost_amount` still unreadable by `authenticated` · 110 `app` functions |

The scope matrix, every refusal preceded by positive controls (the actor provably **holds** the
permission and provably **can see** the colleague's row, so each denial is about scope alone):

* own item → cost **allowed**, selling price **allowed**, value **persisted** (read back as postgres)
* colleague's item, same branch and department → cost **denied**, selling **denied**, figure untouched
* another branch's item → **not even visible**
* direct INSERT priced for someone else → **denied** (INSERT scoped exactly as UPDATE)
* own item once **locked** → denied without `EDIT_LOCKED_COST`; cannot clear the lock to evade it
* finance → **allowed** to edit a locked cost on an item it does not own
* owner → **allowed** to price an item they do not own (the tenant-wide exemption)

## POST-FIX DISCOVERY — what became possible, what became visible

**Visible: nothing.** `has_column_privilege('authenticated', …, 'cost_amount', 'SELECT')` = **false**;
`commission_rate` = **false**. SPEC-139 column privacy fully intact. Notably the employee can now
**write** their own cost yet still cannot **read** the column — write authority and read privacy are
genuinely independent, which is the SPEC-139 design. This surfaced as a real test failure while
writing the guard test: reading the value back had to be done as postgres.

**Possible: cost, selling price — and `commission_rate`.** See BLOCKED-3.

`app.is_my_booking_item` has exactly one caller (the guard), so no other path inherited the predicate.

## NEW BUSINESS DECISION — BLOCKED-3: who may set `commission_rate`?

`app.guard_booking_item_financials` bundles `commission_rate` into `ENTER_SELLING_PRICE` — a SPEC-145
choice predating this package. Granting `ENTER_SELLING_PRICE` per canon therefore also lets an
employee set the `commission_rate` on their own item, i.e. **the basis of their own commission**.

* Canon 28 defines **no** commission permission at all.
* Canon 31 calls `commission_rate` "the reserved basis for sales commission", and SPEC-139 protected
  it from being *read* by colleagues — neither addresses who may *write* it.

This is compensation policy, which evidence cannot settle, so it is not silently resolved.
*Minimum decision:* may a salesperson set the commission rate on their own booking item, or does
`commission_rate` need an authority separate from `ENTER_SELLING_PRICE`? Mitigations already present:
the value cannot be read by colleagues, the cost lock moves the item to finance, and
finance-consequential items pass an approval workflow.

## NOT FIXED (deliberate)

* **SPEC-154-B** — `VIEW_FINANCIAL_DOCUMENTS` is a binary tenant-wide gate and cannot express canon's
  "assigned related only". Deferred on purpose: the correct mechanism is likely a scoped accessor in
  the shape of `app.item_financials`, and WP-04 will settle whether the document-classification
  boundary is its right home. Solving it now risks duplicate architecture.
* WP-03's broad `documents` subscription-gate exemption → WP-04.
* Missing `payment_proof` document type → WP-04.
* 58 never-emitted events, all Class B/C (no producer exists).

## BLOCKED (commercial)

**BLOCKED-1** trial plan tier + duration at provisioning · **BLOCKED-2** `MANAGE_SUBSCRIPTION`
"Limited" for Owner/CEO · **BLOCKED-3** who may set `commission_rate` (new).

## CURRENT STATE

* **126 migrations**, latest `202607053700`, fingerprint `a07d00fbb02a7f5ae39423f5380adaaf` on
  repository, local and Primary.
* 72 tables · 110 `app` functions · 116 policies · 71 permissions · `employee` = 30 permissions.
  Primary holds zero business rows.
* Suite 40 files / 407 assertions / 0 failures. Smoke passes. Both guards CLEAN.
* Git: `main`, tree clean, pushed.

## NEXT STEP

**WP-04 — documents and storage.** Now the largest "schema object exists but the capability does not"
gap: **zero storage buckets and zero storage policies**, while `app.upload_document` records metadata
pointing at storage that does not exist. Trace it end to end — bucket, upload, binary, version,
supersession, access, branch/finance scope, audit, archive — and it also owns three deferred items:
narrowing WP-03's broad `documents` subscription-gate exemption, the missing `payment_proof` document
type (canon 28 requires tenants to upload proof), and the likely home for SPEC-154-B's
document-classification boundary.
