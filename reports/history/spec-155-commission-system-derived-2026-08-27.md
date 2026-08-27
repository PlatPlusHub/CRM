# ORVION — SPEC-155: Commission Is System-Derived

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-27
Author: Claude Opus 5
Scope: Closing BLOCKED-3 with the owner's ratified commission rule (migration `202607053800`).

Predecessor: `spec-154a-scope-aware-financial-guard-2026-08-27.md`.

---

## STATUS — **EARNED → CLOSED**. BLOCKED-3 is **RESOLVED**.

## THE RULE (owner-ratified 2026-08-27)

```
gross_profit        = selling_amount - cost_amount
employee_commission = max(gross_profit, 0) * 10%
company_profit      = gross_profit - employee_commission
```

There is **no employee decision** in setting a commission percentage.

## RECONCILED WITH THE EXISTING MODEL BEFORE IMPLEMENTING

The rule was not applied blindly. The trace found it is **additive, not contradictory**:

* `app.item_financials` already defined `profit` as `selling_amount - cost_amount` — gross profit,
  exactly as the owner rule states. **No competing accounting definition existed.**
* Canon 31: *"`commission_rate` reserves a lightweight path for future sales commission calculation
  **without creating a payroll model**."* Canon reserves the column and defines **no** model, so the
  rule fills a canon gap rather than overriding canon.
* Only three functions referenced `commission_rate` (`create_booking_item`, `item_financials`,
  `guard_booking_item_financials`). **No view, no report, no integration consumed it** — the blast
  radius was small and fully enumerated before any change.

## MECHANISM — overwrite, do not forbid

A permission check would have left the value caller-supplied and would fail open the moment any
future path forgot to check it. A BEFORE trigger that **overwrites** the column makes the caller's
value irrelevant on every path at once — RPC, direct PostgREST DML, batch, and any future writer.
The employee cannot manipulate their compensation because the system never reads what they sent.

**Trigger order is load-bearing.** PostgreSQL fires BEFORE triggers alphabetically, so the trigger is
named `booking_items_derive_commission_rate` — "d" sorts ahead of the existing `..._enforce_*` and
`..._guard_financials` triggers, guaranteeing the system value is in place before the financial guard
evaluates the row. A name sorting after the guard would have made the guard judge the caller's value.

## A REGRESSION THIS AVOIDED

The guard demanded `ENTER_SELLING_PRICE` whenever `commission_rate is not null`. Since the derive
trigger now sets a non-null rate on **every** INSERT, leaving that condition in place would have
silently required `ENTER_SELLING_PRICE` to create a **bare** booking item — breaking any user holding
only `CREATE_BOOKING_ITEM`.

`commission_rate` was therefore removed from the guard's conditions. **This is not a weakening:** the
guard exists to stop a *caller* setting a financial value, and there is no longer a caller value to
authorize — on UPDATE the forced value always equals the previous forced value, and on INSERT it is
always the system constant. `cost_amount` and `selling_amount` keep every check and scope rule
SPEC-145 and SPEC-154-A gave them. Assertion 15 pins the bare-item case permanently.

## VERIFIED

| Check | Result |
|---|---|
| New guard `41_commission_derivation_test.sql` | **15/15** |
| Suite | **41 files / 422 assertions / 0 failures** |
| Smoke | `ALL CHECKS PASSED` |
| Repository guard | CLEAN |
| Database parity | `CLEAN (local proven; primary proven)` |
| repo = local = Primary | **127 migrations**, `8ed3ef86e9df137d0cd5d2fc5eb55a52` |

The decisive assertions are the ones where a caller **supplies** a rate and it does not survive:

* employee (owning the item, provably holding `ENTER_SELLING_PRICE`) inserts with `commission_rate =
  0.90` → accepted, but stored value is **0.10**
* employee then tries a direct `UPDATE … set commission_rate = 0.75` → no error, because there is
  nothing to refuse — and the value is **still 0.10**
* arithmetic: selling 2000 − cost 1000 → gross **1000**, commission **100**, company **900**
* a loss-making item (cost 3000, selling 2500) → commission **0**, company profit **−500** — the
  employee is never charged for a negative margin
* finance sees the figures on an item it does not own (`VIEW_FINANCIAL_DOCUMENTS`)
* a **bare** item still creates under `CREATE_BOOKING_ITEM` alone

## TWO DEFECTS CAUGHT BY EXISTING GUARDS

`app.commission_rate_default()` was written without a pinned `search_path` and with PUBLIC execute.
`05_function_search_path_test.sql` and `10_grant_model_test.sql` both failed on the first run. Fixed
rather than exempted — the invariant is absolute precisely so no future reader has to re-derive
whether a given function is a safe exception.

## POST-FIX DISCOVERY

* **One home for the rule:** a catalog sweep for a hardcoded `0.10` in any other `app` function
  returned **nothing**. Changing the rate is a one-line migration.
* **`commission_rate` consumers:** exactly four functions, all intended.
* **Financial privacy unchanged:** `authenticated` still cannot `SELECT` `commission_rate` or
  `cost_amount`. The new `commission_amount` / `company_profit` are returned only through
  `app.item_financials`, gated by the same `permitted` flag as cost — so they are exactly as
  protected as the figure they derive from.
* **Not per-tenant:** the owner stated a single flat 10% with no per-agency qualification, and
  inventing tenant-configurable compensation would be inventing business policy. If agencies ever
  differ, `app.commission_rate_default()` is the one place it lands.

## NEW DEBT — recorded, classified FIX NOW (not deferred silently)

**`app.create_booking_item` still accepts a `p_commission_rate` parameter that is now silently
ignored.** A caller — including a future UI or n8n — can pass a value, receive no error, and see no
effect. That is a misleading API contract. It was not changed in this migration because removing a
parameter alters the RPC signature, which is an integration-contract change deserving its own
package rather than a tail-end edit. Classified **A — FIX NOW**, scheduled next; not "small, so
ignore it".

## NOT FIXED (deliberate, each tracked)

* **SPEC-154-B** — `VIEW_FINANCIAL_DOCUMENTS` cannot express canon's "assigned related only"
  (binary tenant-wide gate). Deferred to WP-04, which will settle whether the
  document-classification boundary is its right home; solving it now risks duplicate architecture.
* WP-03's broad `documents` subscription-gate exemption → WP-04.
* Missing `payment_proof` document type → WP-04.
* 58 never-emitted events, all Class B/C (no producer exists).

## BLOCKED (commercial)

**BLOCKED-1** trial plan tier + duration at provisioning · **BLOCKED-2** `MANAGE_SUBSCRIPTION`
"Limited" for Owner/CEO. **BLOCKED-3 is now RESOLVED** by the owner rule implemented here.

## CURRENT STATE

* **127 migrations**, latest `202607053800`, fingerprint `8ed3ef86e9df137d0cd5d2fc5eb55a52` on
  repository, local and Primary.
* 72 tables · 112 `app` functions · 116 policies · 71 permissions · `employee` = 30 permissions.
  Primary holds zero business rows.
* Suite 41 files / 422 assertions / 0 failures. Smoke passes. Both guards CLEAN.
* Git: `main`, tree clean, pushed.

## NEXT STEP

1. **Remove `p_commission_rate` from `app.create_booking_item`** (the debt above) — small, contained,
   and an integration-contract change that should not ride along inside another package.
2. **WP-04 — documents and storage**, still the largest "schema object exists but the capability does
   not" gap: zero storage buckets, zero storage policies, while `app.upload_document` writes metadata
   pointing at storage that does not exist. Per the owner directive, the storage provider is an open
   architectural evaluation (Supabase Storage / GCS / Drive / OneDrive-SharePoint / other) to be
   chosen on security, signed URLs, tenant isolation, versioning, retention, recovery, cost and
   scalability — **not** on being free or already present. It also owns three deferred items:
   narrowing the `documents` subscription-gate exemption, the missing `payment_proof` document type,
   and the likely home for SPEC-154-B.
