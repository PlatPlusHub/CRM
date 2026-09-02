# ORVION — SUP-3: Supplier Credit Management Becomes Its Own Permission

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-02
Author: Claude Opus 5
Status: Complete. Migration `202607059700` applied to Primary `vrvtsxexkiiiivlkdxzp`; parity re-proven from Primary. Objective 3 (ceiling enforcement) deliberately NOT implemented — recorded as SUP-4.

---

## 1. SUP-2 closure status

**Closed and still closed.** SUP-2 (`202607059600`, commit `b72caff`) proved that `suppliers.credit_limit_amount` could be SET by three roles that were refused the READ, and charged `VIEW_FINANCIAL_DOCUMENTS` on the write as the correct floor available at the time — canon named no credit permission. SUP-3 replaces that interim floor with the right permission. The hole itself does not reopen: `branch_manager`, `department_manager` and `senior_employee` hold neither `VIEW_FINANCIAL_DOCUMENTS` nor `MANAGE_SUPPLIER_CREDIT`, and `91_..._test.sql` assertion 12 pins that refusal independently of the old model.

## 2. The owner decision, implemented

1. `finance_manager` MUST be able to modify the credit limit — **done**, proven on both doors.
2. Credit-limit management MUST have its own independent permission — **done**, minted, granted, and proven independently grantable *and revocable*.

## 3. Exact permission name

**`MANAGE_SUPPLIER_CREDIT`**, `required_feature_code = 'finance_lite'`, `is_system = true`.

Naming and mechanism are the repository's own, not invented. `permission_key` is a System Catalog whose canon-25 list is headed **"Initial values"**, and two permissions have already been minted past it in migrations — `VIEW_DEPARTMENT_RECORDS` (`202607051400`) and `ARCHIVE_RECORD` (`202607052800`), both via `insert … on conflict (key) do nothing`. The DB holds 72 permissions against canon 25's 69, so the seed list is a historical record, not a live registry. `MANAGE_<noun>` matches `MANAGE_BRANCHES` / `MANAGE_DEPARTMENTS` / `MANAGE_SUBSCRIPTION` / `MANAGE_MARKETING_CAMPAIGN`.

**The feature code was derived, not picked.** `VIEW_FINANCIAL_DOCUMENTS` — which governs *knowing* this same figure — is `finance_lite`. Putting the write on `suppliers` (where `ASSIGN_SUPPLIER` sits) would let a plan entitle the write without the read: SUP-2's shape reproduced one level up, at the plan rather than the role.

## 4. Exact roles granted

**`owner`, `ceo`, `finance_manager`** — verified live on Primary.

`finance_manager` by the owner's rule. `owner` and `ceo` because they are precisely who can set a ceiling today, and the owner directed that no existing legitimate authority be silently removed. `branch_manager` / `department_manager` / `senior_employee` are **not** granted: SUP-2 removed that ability as a proven defect and the owner was told so; this decision adds `finance_manager` without restoring them, and restoring them would both reopen SUP-2 and be a guess at commercial authority. This is the same set canon 28 already gives `EDIT_LOCKED_COST`, the nearest restricted financial authority ORVION has.

## 5. Every credit-limit write path discovered

Enumerated from the catalog, not assumed:

| Path | Governed by |
|---|---|
| `app.create_supplier` (RPC, `p_credit_limit_amount`) | `guard_supplier_credit_authority` on INSERT — **plus** `ASSIGN_SUPPLIER` from the table guard, since creating a supplier is also an act |
| `public.create_supplier` (PostgREST wrapper) | same triggers; wrapper adds reachability and zero authority |
| Direct DML `UPDATE public.suppliers` (PostgREST PATCH) | `guard_supplier_credit_authority` + `guard_write_capability` |
| Direct DML `INSERT public.suppliers` | same |
| Session-less (migrations, seeds, `provision_tenant`, pgTAP fixtures) | exempt by `auth.uid() is null`, canon 35 principle 6 — **pinned by assertion**, not assumed |

`app.supplier_credit` is a reader only. No view, reporting function, scheduled job or integration writes the column — confirmed by searching every `pg_proc` body and `pg_views` definition for `credit_limit_amount`: the only writers are `app.create_supplier` and `public.create_supplier`.

## 6. Exact authorization changes

Two functions, one migration, no new framework:

- **`app.guard_supplier_credit_authority`** — charge changed from `VIEW_FINANCIAL_DOCUMENTS` to `MANAGE_SUPPLIER_CREDIT`. Everything else unchanged: session-less exemption, not-in-play short-circuits, and `is not distinct from` so **clearing** a ceiling still counts as setting it.
- **`app.guard_write_capability`** — a `suppliers` branch. **This is the part that would have silently failed if only the permission had been minted:** `finance_manager` holds no `ASSIGN_SUPPLIER`, and this guard charges it for *any* write to the table, so `finance_manager` would still have been refused and the owner's first rule would have been "implemented" and non-functional.

The rule it learned:

| Write | Requires |
|---|---|
| credit column only | `MANAGE_SUPPLIER_CREDIT` (`ASSIGN_SUPPLIER` neither required nor sufficient) |
| any other column | `ASSIGN_SUPPLIER` (`MANAGE_SUPPLIER_CREDIT` grants nothing) |
| both in one statement | **both** |
| INSERT with a ceiling | **both** |

"Credit-only" is decided by **row-image comparison** (`to_jsonb(new) - 'credit_limit_amount' - 'updated_at'`), not a column list — a column added to `suppliers` later changes the image, so the write stops being credit-only and falls back to `ASSIGN_SUPPLIER`, which is the safe direction to be wrong in. The boolean is set inside the table's own branch, for the reason the function's existing comments already document at length: PL/pgSQL resolves a record field against the actual record type at execution, so naming `new.credit_limit_amount` anywhere this trigger also serves `customers` or `leads` would raise on every one of them.

**Visibility untouched.** The column grant and `app.supplier_credit` were not modified. An actor holding `MANAGE_SUPPLIER_CREDIT` without `VIEW_FINANCIAL_DOCUMENTS` may set the ceiling and still cannot read it — asserted, not assumed.

## 7. Exposure definition used — **none exists; nothing was invented**

ORVION **does** have an authoritative supplier payable: `app.supplier_balance` (cost from `booking_items` where `cost_locked_at is not null`, not archived, status not `cancelled`/`no_show`, minus `payments` with `payment_direction_code = 'supplier_payment'`), published by `reporting.supplier_outstanding`.

It **cannot** be compared to the ceiling, and the reason is measured rather than argued:

```
supplier_balance(Multi Air):   EGP  8000.0000   outstanding
                               USD   600.0000   outstanding      <- two rows, per currency
supplier_credit(Multi Air):         10000.0000                    <- one currency-less scalar
exchange_rates USD->EGP:                     0 rows
tenants.default_currency_code:  written by provision_tenant, read by NOTHING (DEAD-1's class)
```

"Is 8,000 EGP + 600 USD over 10,000?" has no answer in this repository. Canon 25 lists `credit_limit` only as a `supplier_payment_term` value; canon 31 lists the column; SPEC-039 treated it as a physical column choice. No canon names the operation subject to the ceiling, its currency, the behaviour exactly at the limit, or whether `payment_term_code = 'credit_limit'` is a precondition. No Batch-4 spec defines it and AP `supplier_bills` (BF-7) is unbuilt.

Per the owner's own instruction for this branch, the sub-part stopped and is recorded as **SUP-4**, with the smallest decision required: **(1)** in what currency the limit is denominated; **(2)** which operation is refused when it would be breached — locking a booking-item cost is the only existing event that raises the payable; **(3)** whether it binds on every supplier or only where the payment term is `credit_limit`.

## 8. Exact enforcement point

For *who may set* the limit: two BEFORE row triggers on `public.suppliers` — `suppliers_guard_credit_authority` (INSERT/UPDATE) and `suppliers_guard_write_capability` (INSERT/UPDATE). Both are on the table, so PostgREST, the RPC, and any future n8n or UI caller meet the same rule; none of it lives in a client. For *the ceiling being exceeded*: **no enforcement point exists** — see §7.

## 9. Concurrency analysis

**For what shipped: no race is possible.** Neither guard performs a read-modify-write on a mutable aggregate. Each resolves the caller's permissions and admits or refuses the row in front of it; two concurrent credit-limit writes are serialised by the row lock PostgreSQL already takes on `UPDATE`, and the outcome is last-writer-wins on a single scalar, which is the semantics of the column and not a ceiling calculation.

**For SUP-4, whoever builds it:** the owner is right that a ceiling two simultaneous transactions can both pass is not a ceiling. ORVION's only existing financial ceiling is `payment_allocations_within_invoice_total` (FIN-10), and reading its definition settles the architectural question: it is a **`CONSTRAINT TRIGGER … DEFERRABLE INITIALLY DEFERRED`** that re-reads `sum(allocated_amount)` at commit and compares it to the invoice total. That is the existing pattern to reuse — but it is a **deferred re-read, not a lock**. Whether two transactions committing simultaneously can both pass it is **UNPROVEN**: I did not reproduce it, and I am not claiming FIN-10 is defective. Settling it belongs to the package that builds supplier-credit enforcement, which must not assume the deferral is sufficient.

## 10. Mutation-test matrix

`91_supplier_credit_permission_test.sql` — **26 assertions**, all passing. Every mutation is verified to have actually happened *before* behaviour is measured.

| # | Mutation / case | Verified first | Result |
|---|---|---|---|
| 1–3 | permission exists; feature code equals the READ permission's; role set | — | exactly `ceo,finance_manager,owner` |
| 4–7 | finance_manager, credit-only write | `has_permission` echoed both ways | succeeds; **value read back** via the gated reader |
| 8 | same actor, credit **+ phone** | — | refused — the controlled counterexample |
| 9 | same actor, phone only | — | refused |
| 10–13 | senior_employee (ASSIGN_SUPPLIER) | echoed | ceiling refused; ordinary edit still works |
| 14–15 | **GRANT** `MANAGE_SUPPLIER_CREDIT` to a role lacking it | `has_permission` = true asserted first | previously-refused write now succeeds |
| 16–18 | that actor's visibility | `has_permission('VIEW_FINANCIAL_DOCUMENTS')` = false asserted | still refused the column read **and** `supplier_credit` returns `permitted=false` |
| 19–20 | **REVOKE** | `has_permission` = false asserted first | write refused again |
| 21–22 | RPC door with / without a ceiling | — | refused / allowed |
| 23–25 | **PAR-4 injection** on `guard_supplier_credit_authority` | trigger counted present first | dropped → write lands; restored → refused |
| 26 | owner | — | retains authority |

**The injection target was chosen deliberately.** It uses a credit **+ phone** write, not a credit-only one: on a credit-only write both guards now demand the same permission, so dropping one leaves the other, the `lives_ok` fails and the paired `throws_ok` keeps passing on the survivor **while measuring nothing**. Adding an ordinary column makes the write not credit-only, so the table guard charges `ASSIGN_SUPPLIER` (which the actor holds) and the credit guard is the sole refuser.

## 11. Regression results

**Test 90 was corrected, not merely re-run** — and it failed first, which is how it was found. Its PAR-4 mutation dropped `suppliers_guard_credit_authority` on a credit-**only** write and asserted the write then succeeded; SUP-3 gave `guard_write_capability` a second charge on exactly that write, so the mutation was masked. This is the **test-85 lesson recurring the moment a second enforcement point appeared** — the same defect class, in a file written one package earlier to document that class. Its mutation pair now names a second column, with the reason recorded at the site, and its header records that SUP-2's permission choice was superseded.

Pass A **91 files / 1273 assertions** (was 90/1247). Pass B, run without reset under all six HTTP suites' residue: **91 / 1273**. Smoke: `ALL CHECKS PASSED (75 tables, …)`.

## 12. HTTP results

Six suites, **395 assertions, 0 failed** (was 390): api 29 · lifecycle 107 · journey 74 · **role 85** · care 40 · storage 60.

Five new assertions in `verify_role_journeys.ps1` prove the owner's rule over the wire, as `finance_manager` holding no `ASSIGN_SUPPLIER`. The three PATCHes differ **only in their column list**, which is what makes it a controlled comparison:

```
PATCH {phone}                         -> refused
PATCH {credit_limit_amount, phone}    -> refused
PATCH {credit_limit_amount}           -> 204, and the value really moved 30000 -> 45000
```

## 13. Primary parity

All three values read **from** Primary, never derived from the repository (GUARD-1):

| | Primary | Local |
|---|---|---|
| ledger | `186 \| 8de18286d9f215585c7d41b56f5a8c18` | identical |
| function surface | `1c27a181022140ac63baa772354db54b` (254) | identical |
| structural surface | `ee4c9cda6ce4396f4f750bab9904cd8b` (3,393 across ten surfaces) | identical |

`MANAGE_SUPPLIER_CREDIT` verified granted on Primary to `ceo,finance_manager,owner`. **GUARD-1 recurred as usual** — `apply_migration` stamped its own ledger version — and was normalised to `202607059700` before the fingerprint was read.

## 14. Migrations changed

One, additive: **`202607059700_supplier_credit_is_its_own_authority.sql`**. Both function changes are `create or replace`; `guard_write_capability` was replaced from its **live definition** so nothing from SEC-1b / SEC-1c / LIC-3 / PP-4 was lost, with only the marked SUP-3 region added. Both inserts are `on conflict do nothing`, so re-application and `db reset` are idempotent. No column, table, constraint, policy, grant or index changed — the structural counts are unchanged at 3,393.

## 15. Governance / canonical files changed

- **`_ORVION_CANONICAL/28_permissions_matrix.md`** — item 5 in the existing *"Amendments ratified with this model"* list, which is exactly where `VIEW_DEPARTMENT_RECORDS` is recorded; heading widened to *"owner directives 2026-08-24 and 2026-09-02"*. No new document, no duplicated narrative.
- **`MASTER_GAP_REGISTER.md`** — SUP-3 rewritten from open owner decision to decided-and-implemented; **SUP-4** added.
- **`manifest.md`** — live state, `Last Completed`; SUP-3 leaves the open-decisions line and SUP-4 joins it.
- **`MASTER_EXECUTION_PLAN.md`**, **`reports/README.md`**, this report.

**Canon 25 was deliberately not touched.** Its list is headed "Initial values" and two prior minted permissions are absent from it; the live registry is `public.permissions`, and canon 28 is where the ratification is recorded.

## 16. Repository guard

`check_repository_consistency.ps1` — **REPOSITORY CONSISTENCY: CLEAN**, 18 checks. Check 11 resolves all 15 manifest decision IDs (SUP-4 in, SUP-3 out); Check 15 confirms the manifest's suite figures match the repository.

## 17. Database guard / parity

`check_database_parity.ps1` with all three Primary values — **DATABASE PARITY: CLEAN (local proven; primary ledger, functions and structure proven)**.

## 18. Git commit and tree state

`202607059700` + 2 tests + 1 HTTP suite + 6 governance files. Working tree clean, nothing unpushed.

## 19. Remaining limitations

1. **The ceiling still enforces nothing** — SUP-4, blocked on three owner questions (§7). `MANAGE_SUPPLIER_CREDIT` governs *who may set* the limit; it does not make the limit bind.
2. **`finance_manager` still cannot create a supplier, or edit one.** It holds no `ASSIGN_SUPPLIER`, which is pre-existing and was neither introduced nor widened here. It is also the correct reading of the owner's instruction — the decision was about credit management, and the permissions are required to stay orthogonal.
3. **SUP-2's "learn by writing" argument is deliberately narrowed, on the owner's instruction.** SUP-2 reasoned that an actor who sets a value knows it, so the write must cost at least the read. Under SUP-3 an actor granted `MANAGE_SUPPLIER_CREDIT` alone can set a ceiling without being able to read the existing one. That is a different and defensible position — they hold explicit financial authority for exactly this field, and the prior value stays hidden — and the owner required the permissions be orthogonal. It is stated rather than buried because it is a real change in the argument, not just in the code. All three seeded holders currently hold both permissions, so no actor is in that position today.
4. **FIN-10's simultaneous-commit behaviour is UNPROVEN** (§9). Not claimed as a defect; flagged for SUP-4's implementer.
5. `tenants.default_currency_code` has a producer and **no consumer** — DEAD-1's class, found while measuring §7, not fixed here.
