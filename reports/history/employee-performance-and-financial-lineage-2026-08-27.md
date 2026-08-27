# ORVION — SPEC-159: Employee Performance, and the Financial Lineage Pass That Preceded It

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-27
Author: Claude Opus 5
Scope: The owner's employee-performance requirement (§7–§11 of the 2026-08-27 continuation
directive), the financial-lineage re-introspection it required first (§24), and the defect that
re-introspection found (migrations `202607054200`, `202607054300`).

Predecessor: `subscription-licensing-platform-authority-alignment-2026-08-27.md`.

---

## 1. SESSION OBJECTIVE

Deliver SPEC-159 — a personal operational and financial performance view for every employee,
enforced in the database — but **only after** proving the business data lineage the owner demanded:
what exactly constitutes "my sale", where the money comes from, and whether there is genuinely one
financial truth. The directive was explicit that SPEC-159 must *not* begin by creating a report view.

That sequencing was the whole value of the session: the lineage pass found a defect that would
otherwise have had a report built on top of it.

## 2–4. ENVIRONMENT AND STARTING STATE

| | |
|---|---|
| Starting commit | `144898e` |
| Starting migrations | **130**, latest `202607054100`, fingerprint `538237ee27a3aa6a41da26f6ac146b3f` |
| Repository guard | CLEAN |
| Database parity | CLEAN (local proven; primary proven) — all three agreeing |
| Primary ref | `vrvtsxexkiiiivlkdxzp`, re-read live |
| Tree | clean, `main` == `origin/main` |

Verified by running the guards and reading both ledgers through MCP, not from this session's memory.

## 5–6. DISCOVERIES AND EVIDENCE

### The lineage answers (these were the point of the pass)

* **Whose sale is it?** Commission attaches to `sales_owner_user_id`. Derived from canon, not
  guessed: canon 31 states `commission_rate` reserves the basis for *sales* commission, and
  `booking_items` carries a dedicated sales triple (`sales_owner_user_id` /
  `sales_owner_department_id` / `sales_owner_branch_id`) distinct from `owner_*` and
  `operational_owner_user_id`. **`app.create_booking_item` sets all three to the creator** and no
  reassignment path exists anywhere, so the fields are structurally distinct and operationally
  identical today.
* **Who owns the booking after a quotation?** `app.create_booking` sets `owner_user_id` to the
  *booker*, not the quotation's owner. Since commission lives on the **item**, not the booking, a
  report keyed on the item's sales owner is unaffected by that — worth knowing, not worth changing.
* **One financial truth: CONFIRMED.** A repository-wide sweep for a second `selling_amount -
  cost_amount` found none. `app.booking_item_profit` delegates to `app.item_financials`;
  `reporting.booking_item_profit` delegates to that. The new view delegates too.
* **Refunds do not alter gross profit, and that is coherent.** `record_refund` records a cash
  movement against a booking; profit is item-level (`selling − cost`), and a cancelled item is
  already excluded from `app.booking_item_profit`. Cash and margin are deliberately separate
  concerns. No change made; the reasoning is recorded so the next reader does not "fix" it.
* **Airline is not a missing dimension.** `airline` is a value of the `supplier_type` catalog, and
  canon 32 explicitly defers airline reference tables to the flight-ticketing feature. "Airline
  performance" is therefore supplier performance filtered by `supplier_type_code = 'airline'`.
  Inventing an airline column would have created a second vocabulary for a concept the catalog owns.

### The defect the pass found — FIN-1

`booking_item_passengers` carries `cost_amount_override` and `selling_amount_override`: the
per-passenger fare and cost. **Three holes, each proven live:**

```
has_column_privilege('authenticated','booking_items','cost_amount','SELECT')                = false
has_column_privilege('authenticated','booking_item_passengers','cost_amount_override', ...) = TRUE
```

1. **Privacy.** SPEC-139 removed the table-level SELECT from `booking_items` and granted a column
   list. This sibling table kept a plain table-level SELECT, so every column — including both
   financial ones — was readable. RLS makes that reachable rather than theoretical:
   `booking_item_passengers.scope_isolation` admits any row whose **parent booking item is visible**,
   and `booking_items.scope_isolation` grants department/branch visibility of a colleague's items.
   One employee could read a colleague's per-passenger cost — the exact SEC-4 threat SPEC-139 exists
   to prevent.
2. **Authority.** `app.link_passenger_to_booking_item` authorizes only `CREATE_BOOKING_ITEM`, then
   writes both financial columns. It never asks for `ENTER_COST`/`ENTER_SELLING_PRICE` and never
   checks whose item it is. `guard_booking_item_financials` protects `booking_items` and does not
   fire here — so an employee could attach cost and selling figures to **any item they could see**,
   including a colleague's. Precisely what SPEC-154-A made impossible one table over.
3. **Direct DML.** `authenticated` held INSERT and UPDATE on the table, so neither hole needed the
   RPC at all.

**Why it survived four financial packages:** `link_passenger_to_booking_item` had **zero test
coverage** — no test file referenced it or the table. A guard nobody wrote cannot fail.

## 7–8. DEFECTS FIXED

**SPEC-159-A (`202607054200`) — FIN-1 closed on all three paths.**
* Table-level SELECT revoked; column-level SELECT granted on the five non-financial columns only.
  A column list rather than a policy, because a table grant silently covers columns added later —
  which is how this hole appeared.
* `app.guard_passenger_financials()` requires `ENTER_COST` / `ENTER_SELLING_PRICE` when an override
  is written, and scope-checks the **parent item** through the existing `app.is_my_booking_item`,
  with the same `has_tenant_wide_read()` exemption SPEC-154-A uses. Same permissions, same scope
  test, same shape — no second authorization model.
* A trigger, not an RPC check, because direct DML was the unguarded path.
* Named `booking_item_passengers_guard_financials` so "g" sorts after the existing
  `..._enforce_subscription_write_gate` — the subscription gate still decides first, matching the
  relative ordering `booking_items` already uses.
* Linking a passenger with **no** price still needs only `CREATE_BOOKING_ITEM`; operational work is
  not financial work. Same reasoning that keeps a bare booking item creatable (SPEC-155).
* Scalar variables, not a RECORD, for the parent lookup: this trigger runs **before** the foreign key
  on `booking_item_id` is validated, so a bogus parent really can yield no row — and plpgsql binds
  referenced variables as query parameters, so an unassigned RECORD field raises 55000 before any
  guard can short-circuit. That is the trap that broke `create_booking` on the direct path.

**SPEC-159 (`202607054300`) — `reporting.my_sales_performance`.**
* `security_invoker` view in the existing `reporting` schema — the established pattern, not a new one.
* Money comes from `cross join lateral app.item_financials(bi.id)`, exactly as
  `reporting.booking_item_profit` already does. A view naming `cost_amount` directly would fail for
  every employee, so this is what keeps SPEC-139 intact rather than weakened.
* Scoped by `sales_owner_user_id = app.current_user_id()`: a colleague's rows are **absent, not
  masked**. `item_financials` would have nulled the money anyway, but a masked row still discloses
  that a colleague made a sale, to which customer, through which supplier, on which date.
* Excludes archived and `cancelled`/`no_show` items — the rule `app.booking_item_profit` already
  applies. A cancelled sale earns no commission; reused, not re-decided.
* **LEFT** joins to `bookings`/`customers`/`suppliers`. An item can be the caller's while its parent
  booking is not visible to them (`booking_items.scope_isolation` admits on ownership alone). An
  inner join would silently drop that item and **under-report the employee's own commission** — a
  worse failure than a null booking reference.
* Personal for **every** role, tenant owner included: it answers "what did I sell", never "what did
  the branch sell". A personal report that widens for privileged roles is a management report in
  disguise.

**Why exactly one view**, when the owner listed leads, quotations, customers and bookings too: the
employee can already read their own `leads`, `quotations`, `customers` and `bookings` directly under
RLS (`authenticated` holds SELECT on all four, each carrying `owner_user_id`), and
`reporting.sales_activity` / `reporting.lead_performance` already aggregate bookings and leads per
owner. The **only** thing impossible without a new object is the money, because those columns are
deliberately unreadable. Three more views would have duplicated what RLS already serves.

**Filters and export needed no mechanism.** Every filter the owner listed — today, date range, month,
year, customer, supplier, airline — is a WHERE clause over columns the view exposes, and PostgREST
serves the same view as CSV. **No EXPORT permission was invented:** canon 25 defines none, and one
that every role would hold is not a control.

## 9. DEFECTS INTENTIONALLY NOT FIXED (each recorded, none hidden)

* **DEAD-1 — the passenger override columns have no reader.** No function, view or report consumes
  them. The lazy reading is "dead columns, drop them"; that was rejected. Per-passenger pricing is
  not speculative in a travel agency (two passengers on one booking routinely carry different
  fares), canon 06/24 model the passenger as first-class, and AGENTS.md §3 keeps an inevitable domain
  structure even with no current consumer. Dropping them trades a five-minute fix for a future
  structural migration. **They are secured now and wired to the financial model when per-passenger
  pricing is actually built** — recorded in the plan, not resolved by amputation.
* **DEAD-2 — `refunds.booking_item_id` and `payments.booking_item_id` have no producer.**
  `record_refund` accepts a booking, never an item. Item-level refund/payment attribution is a
  genuine capability gap; it does not affect gross profit (see §5) and is recorded for the finance
  package rather than half-built here.
* **Management aggregate reporting** — deliberately out of scope. Conflating it into a personal view
  is precisely how a personal report becomes an accidental management report.

## 10. BLOCKED

* **BLOCKED-4 — BUSINESS DECISION.** Once booking-item ownership becomes transferable (it is not
  today), does commission follow the new sales owner or stay with the original seller? The view keys
  on `sales_owner_user_id` so it stays correct either way; the *policy* is unresolvable from
  evidence. Does not block anything now.
* **BLOCKED-5, CANON-26-1, LIC-1, PLAN-1** — unchanged from the predecessor report.

## 11. TESTS

| Guard | Result |
|---|---|
| `44_passenger_financial_authority_test.sql` (new) | **12/12** |
| `45_employee_performance_test.sql` (new) | **10/10** |
| Suite | **45 files / 496 assertions / 0 failures** |
| Smoke | `ALL CHECKS PASSED` (73 tables, 69/591 catalog) |

Both new guards lead with positive controls, so no denial can be explained by a missing permission or
an empty fixture: the actor provably **holds** `ENTER_COST` and `ENTER_SELLING_PRICE`, provably
**holds** `CREATE_BOOKING_ITEM`, and provably **can see** the colleague's booking item. The decisive
assertions:

* A prices a passenger on their own item → allowed, **and the figures are read back** as postgres —
  "it did not throw" is not evidence of a write.
* A prices a passenger on a **colleague's** item → denied, for cost and for selling price separately.
* A links a passenger to a colleague's item with **no** price → still allowed.
* A **direct UPDATE** of a colleague's per-passenger cost → denied (the trigger, not the RPC).
* A **direct SELECT** of that column → denied at the SQL level.
* The report shows A exactly one row (cancelled and archived excluded), `2000/1000/1000` and
  `100/900` — the owner's rule end to end through the report.
* The colleague's row is absent, and **naming the colleague's item id directly does not surface it**.
* Summing the report yields A's own 900, never the tenant total of 1900.
* B's own view is symmetrical — the scope follows the caller, not the fixture.
* The **tenant owner sees zero rows** despite `VIEW_ALL_BRANCHES`: tenant-wide read does not widen a
  personal report.

## 12. REGRESSIONS FOUND

None. All 43 pre-existing test files continued to pass unchanged, including
`23_financial_privacy_test.sql`, which is the guard most likely to notice a mistake in this area.

## 13. CROSS-PATH SWEEP (owner directive §2 / §16)

Both changes are financial-authority changes, so the catalog was asked which paths now meet the new
rule — answered by query, not by inspection:

* **Writers of `booking_item_passengers`: exactly one function**, `link_passenger_to_booking_item`,
  and it is **SECURITY INVOKER** (`prosecdef = false`). No SECURITY DEFINER path bypasses the guard.
* **Readers: none.** No view, function or report selects from the table (DEAD-1).
* **Triggers: exactly two**, in the intended alphabetical order (`_enforce_subscription_write_gate`
  then `_guard_financials`).
* **Batch / scheduled / multi-tenant:** none touch this table, verified against `cron.job` and the
  function catalog. A **raising** trigger is therefore correct here — this is a single-tenant
  interactive write path, not a WP-03-shaped multi-tenant batch where one tenant's refusal could
  abort another's run.
* **RLS:** no policy altered. Only grants and one new trigger, so no policy branch could be dropped
  (owner directive §17).
* **Financial calculation:** unchanged. The overrides have no reader, so nothing recomputes.
* **The new view widens nothing:** `security_invoker` means its joins run under the caller's RLS, and
  its LEFT joins yield NULLs rather than rows the caller could not otherwise see.

## 14–15. DEPLOYMENT AND PARITY

Both migrations applied to Primary and reconciled from the `apply_migration` version stamp to their
file versions. Primary re-read live afterwards, not assumed:

```
pax_cost_readable = false   pax_id_readable = true    pax_table_select = false
pax_triggers = 2            view_grant = true         security_invoker = "true"
reporting_views = 8
```

`DATABASE PARITY: CLEAN (local proven; primary proven)` — repository, local and Primary all at
**132 migrations**, fingerprint `a08dfe6c109937ab82932332d7944fd4`.

## 16–17. COMMIT AND PUSH

See the final commit on `main`; pushed to `origin/main` and the remote re-verified. Working tree
clean.

## 18. EXACT NEXT STEP

**WP-04 — documents and storage.** Now the largest "schema object exists but the capability does
not" gap: **zero storage buckets and zero storage policies**, while `app.upload_document` records
metadata pointing at storage that does not exist. Per the owner directive §14 the provider is a
genuine architectural evaluation (Supabase Storage / GCS / Drive / OneDrive-SharePoint / other)
decided on tenant isolation, private objects, signed URLs, versioning, retention, deletion, recovery,
backups, size limits, operational simplicity, scalability, auditability and n8n integration —
**not** on cost or on Supabase already being present.

A discovery pass was run for it before this session closed, so WP-04 starts from evidence rather than
a re-scan. Recorded in `MASTER_EXECUTION_PLAN.md` Batch 6 item 3, and proven live on Primary:

* `storage.buckets` = **0**, `storage.objects` = **0**, policies in schema `storage` = **0**, while
  `document_versions.storage_path` is **NOT NULL** — every upload is required to record a path into
  storage that does not exist.
* **DOC-1 — the storage path is caller-supplied.** `app.upload_document` takes `p_storage_path` as a
  parameter. The moment buckets exist, nothing stops a caller writing a path under another tenant's
  prefix: a cross-tenant path designed in before storage is created. The fix shape is already proven
  here — *derive* the path rather than validate it, exactly as SPEC-155 derives the commission rate.
* **DOC-2 — no `payment_proof` document type.** The catalog holds 12 values and none is a payment
  proof, while `subscription_payment_proofs.document_id` is NOT NULL and
  `document_links.subscription_payment_proof_id` exists. The linkage is modelled end to end and the
  vocabulary is missing, so a tenant's bank-transfer proof can only be filed as `other`.

It also owns narrowing WP-03's broad `documents` subscription-gate exemption and SPEC-154-B's
document-classification boundary.

## 19. NEWLY DISCOVERED QUESTIONS

* Should per-passenger overrides, once given a reader, **replace** or **supplement** the item-level
  `cost_amount`/`selling_amount` in `app.item_financials`? Two coherent models exist (per-passenger
  as the authoritative detail with the item as a rollup, or the item as authoritative with overrides
  as annotation). Not asked of the owner yet — it becomes a real decision only when per-passenger
  pricing is built, and evidence may settle it then.
* Item-level refund and payment attribution (DEAD-2): does the agency need per-item refunds, or is
  booking-level sufficient? An operational question for the finance package.

## 20. PLAN CHANGES

`MASTER_EXECUTION_PLAN.md` Batch 6 **extended, never replaced**: SPEC-159 and SPEC-159-A recorded as
done, with SPEC-159-A explicitly logged as a **prerequisite discovered mid-package and inserted
rather than skipped** (owner directive §21). DEAD-1, DEAD-2 and the per-passenger-pricing question
added as tracked items. `MASTER_GAP_REGISTER.md` gains **FIN-1** (resolved).

**Governance change, owner directive §22 — the manifest leanness problem fixed at the cause.**
`manifest.md` had been trimmed three times in two sessions to stay under its 7000-character budget,
which is a treadmill, not a fix. The actual cause was that the manifest was restating content whose
authoritative home is elsewhere: full definitions of every open decision (owned by
`MASTER_GAP_REGISTER.md`) and full package narratives (owned by `MASTER_EXECUTION_PLAN.md` and the
session reports). Both were replaced by ID lists and pointers. **No history was deleted** — it lives
in its one authoritative home and is now referenced rather than duplicated. The manifest is
**5455 characters**, with real headroom for the first time in three sessions, and the budget was not
raised.
