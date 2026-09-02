# ORVION — SUP-2: A Ceiling You May Not Read Is a Ceiling You May Not Set

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-02
Author: Claude Opus 5
Status: Complete. Migration `202607059600` applied to Primary `vrvtsxexkiiiivlkdxzp`; parity re-proven from Primary.

---

## 1. What this session was

Batch 6 resumed. `MASTER_EXECUTION_PLAN.md` line 1049 named the next item without ambiguity — **"NEXT SLICE: the remaining Batch-6 tables — the table-by-table audit below still owns the order"** — so this is that slice, and no other work was started.

Boot sequence completed before any engineering: `AGENTS.md` → `GOVERNANCE.md` → `manifest.md` (`Active Change Request: None.`) → roadmap → latest session report; `check_repository_consistency.ps1` **CLEAN, exit 0, 18 checks**.

---

## 2. DISCOVERED — how the slice was chosen

The previous slices each chose their subject by *ranking the surface and attacking the ranking first*. That method was followed rather than a list, and **three candidate classes were discarded by the measurement itself** before a fourth produced a defect. Recording them matters as much as the finding: they are now measured facts, not unexamined surface.

| Candidate class | Measured result | Verdict |
|---|---|---|
| Direct `DELETE` authority | `authenticated` holds **zero** DELETE on all 75 tables (`service_role` holds all 75) | Closed by design (B5) — not a slice |
| A granted command with no RLS policy | Zero rows: every SELECT/INSERT/UPDATE grant to `authenticated` has a matching policy | Clean |
| `SECURITY DEFINER` hygiene | All 24 DEFINER functions reachable by `authenticated` pin `search_path=""`; **none** executable by `anon` | Clean |
| **Columns `authenticated` cannot SELECT but CAN INSERT/UPDATE** | **5 columns across 3 tables** | **The slice** |

That fourth query is the detector. Its result:

| Table | Column | Write authority |
|---|---|---|
| `booking_item_passengers` | `cost_amount_override`, `selling_amount_override` | `guard_passenger_financials` — ENTER_COST / ENTER_SELLING_PRICE, scope-aware (SPEC-159-A) |
| `booking_items` | `cost_amount`, `commission_rate` | `guard_booking_item_financials` — ENTER_COST, scope-aware (SPEC-139 / 154-A) |
| **`suppliers`** | **`credit_limit_amount`** | **`guard_write_capability` only → ASSIGN_SUPPLIER** |

### The finding was attacked before it was trusted

Two counter-hypotheses were tested, and the first one nearly killed it.

**(a) "Write-without-read is ORVION's ratified pattern anyway."** `booking_items.cost_amount` is written on ENTER_COST (6 roles) and read behind VIEW_FINANCIAL_DOCUMENTS (3 roles) — the same asymmetry, apparently ratified. **False.** `app.item_financials` grants the read on `VIEW_FINANCIAL_DOCUMENTS` **or ownership of the item**, so the salesperson who entered a cost reads it back. `app.supplier_credit` has **no relationship escape** and a supplier has no assignee to escape by. The pattern is coherent on `booking_items` and incoherent on `suppliers`.

**(b) "The role sets are identical, so the gap is behaviour-neutral."** This is precisely the reasoning that correctly closed CREATE_COMPLAINT/RESOLVE_COMPLAINT in the care re-audit. **Not so here** — measured:

```
ASSIGN_SUPPLIER          -> branch_manager, ceo, department_manager, owner, senior_employee
VIEW_FINANCIAL_DOCUMENTS -> ceo, finance_manager, owner
gap                      -> branch_manager, department_manager, senior_employee
```

**The defect, stated exactly:** an actor who SETS a value KNOWS it — they supplied it. For those three roles, SUP-1's read gate therefore withheld nothing at all: they learn the ceiling by writing it. SUP-1's guarantee was defeated by SUP-1's own untouched write path.

---

## 3. VERIFIED — reproduced before anything was changed

As `senior_employee`, in one session, with the refusal established **first** so the write is a write by someone provably ignorant of the value:

```
CONTROL 1  assign_supplier = t | view_financial = f
CONTROL 2  select s.name ...           -> 'Nile Air'          (row visible; not count(*))
CONTROL 3  select credit_limit_amount  -> ERROR 42501 permission denied for table suppliers
CONTROL 4  supplier_credit(...)        -> permitted=f, credit_limit_amount=(null)
DEFECT A   update ... set credit_limit_amount = 999999   -> UPDATE 1
DEFECT B   app.create_supplier('Delta Air','airline',null,null,null,500000) -> new supplier
PROOF (read back with rights)   Delta Air 500000.0000 | Nile Air 999999.0000
```

Both writes verified by reading the values back with rights — never by "it did not throw".

**Why it survived two packages that both read this exact column.** Each recorded the other as owning the half it skipped:

- `86_supplier_credit_visibility_test.sql` opens: *"SEC-1c closed the WRITE half (a trainee rewrote `credit_limit_amount` 1000 -> 999999). This file pins the READ half."*
- `202607059200` (SUP-1) closes: *"NOT CHANGED: `app.create_supplier` still accepts the limit and still writes it; the write path and its ASSIGN_SUPPLIER charge are untouched."*

Both statements are true. SEC-1c closed the write half **against a trainee**, who holds neither permission. The property proven was *"the weakest actor is refused"*; the property assumed was *"the authority is sufficient"*. The middle of the role ladder was never any proof's subject — `AGENTS.md §6`'s standing rule, in its own repository.

---

## 4. FIXED

`supabase/migrations/202607059600_a_ceiling_you_may_not_read_is_a_ceiling_you_may_not_set.sql` — `app.guard_supplier_credit_authority()` plus a BEFORE INSERT OR UPDATE trigger on `public.suppliers`.

**Shape copied, not invented.** `app.guard_passenger_financials` (SPEC-159-A) already solves the identical problem one table over, and its structure is followed exactly: session-less exemption → no-op when the field is not in play → charge the financial permission. Its *scope* check is deliberately **not** copied: `booking_items` has an assigned owner and canon 28 reads "assigned" for ENTER_COST; a supplier is tenant master data with no assignee.

**Permission derived, not chosen — nothing minted.** Canon 28 assigns the field no authority (canon 25 lists `credit_limit` only as a payment *term*; canon 31 lists the column). That silence is why SUP-1 had to derive the read permission from `app.supplier_balance`; the write is derived from the same source, and the floor is forced rather than preferred: **the write must cost at least the read.**

Three details that are load-bearing:

- `is not distinct from`, not `=` — NULL is a real value, so **clearing** a ceiling is a change to it. `=` would have let an unprivileged actor erase the limit silently, the more dangerous direction.
- `app.authorize`, not `app.has_permission` — `authorize` composes the MFA step-up, and every VIEW_FINANCIAL_DOCUMENTS holder is in `app.requires_mfa`'s role set.
- `revoke all ... from public` — **added because an existing class guard caught its absence.** `10_grant_model_test` assertion 5 failed on the default EXECUTE-to-PUBLIC grant on the first run. The guard doing exactly its job.

---

## 5. Cross-path impact sweep (`AGENTS.md §3 5b`)

**Q1 — which existing execution paths now meet this rule?**

| Path class | Result |
|---|---|
| Single-tenant interactive (RPC `create_supplier`; PostgREST PATCH) | Both refused for the gap roles, both proven |
| Session-less / platform (migrations, seeds, `provision_tenant`, pgTAP fixtures) | Exempt by `auth.uid() is null`; **pinned by assertion 15**, not assumed |
| Batch / scheduled / integration | None writes `suppliers`; no scheduled job touches the table |
| Administrative | `service_role` unaffected |

**Q2 — what CONSUMES or DERIVES FROM the structure this package changed?** This is the question that found the real casualty. Readers: `app.supplier_credit` only (no view, no reporting object). Writers: `app.create_supplier` and direct DML. But **`85_write_capability_on_update_test.sql` derives from the assumption that `suppliers_guard_write_capability` is the only guard on that column** — its PAR-4 mutation drops that trigger and asserts the write then succeeds. With a second guard present the `lives_ok` half would fail and, worse, the `throws_ok` half would keep passing on the *other* trigger's refusal, **quietly measuring nothing**. Its three supplier assertions now name `phone`, so they pin exactly the trigger they name; the ceiling column is owned by test 90, which carries its own defect injection. The reason is recorded at the site.

`86_supplier_credit_visibility_test.sql`'s header sentence was corrected rather than rewritten — the belief it records is what let the gap survive.

---

## 6. Tests

`supabase/tests/90_supplier_credit_write_authority_test.sql` — **15 assertions**: the trigger covers both write ops; the role-set gap counted (3, with a note that a change is a signal to re-read, not to re-number); the actor genuinely holds ASSIGN_SUPPLIER and not VIEW_FINANCIAL_DOCUMENTS; the read refused; **positive control** that an ordinary supplier field is still editable *and that the write landed*; refusals for set, **clear**, and the RPC; a ceiling-less supplier still creatable; **PAR-4 defect injection** (drop → write succeeds → restore → refused); the owner still reads the real ceiling; the session-less path still writes one.

`scripts/verify_role_journeys.ps1` — **9 HTTP assertions** beside SUP-1's read half, because PostgREST serves PATCH on `suppliers` next to the RPC. A `Invoke-Patch` helper was added.

**The HTTP claim was proven, not inferred.** Defect injection at the wire against the suite's own fixture:

```
with the guard      PATCH -> 403   ceiling 30000    (unchanged)
guard dropped       PATCH -> 204   ceiling 999999   (moved)
guard restored      PATCH -> 403   ceiling 999999   (unchanged)
```

---

## 7. NOT FIXED

**SUP-3 — recorded, deliberately not answered.** With SUP-2 in force the ceiling is settable by **{owner, ceo}**. `finance_manager` — the role most obviously responsible for supplier credit terms — holds VIEW_FINANCIAL_DOCUMENTS but not ASSIGN_SUPPLIER, so it cannot write `suppliers` at all. **That inability is pre-existing** (`guard_write_capability`, SEC-1b) and was neither introduced nor widened here. Whether `finance_manager` should hold ASSIGN_SUPPLIER, or supplier credit deserves a canon-28 permission of its own, is commercial. SUP-2 is correct under either answer — both would only *widen* who may set a ceiling — so it does not block. Guessing between them would be the invention this audit's non-goals forbid.

**Also observed, deliberately out of scope:** `credit_limit_amount` is read by `app.supplier_credit` and **enforced by nothing** — no path refuses a booking or a payment because a supplier's exposure exceeds its ceiling. That is why SUP-2 is Medium rather than High: raising the ceiling bypasses no control, because there is no control. Whether one should exist is a finance capability, not a defect, and belongs to Batch 4.

---

## 8. Verification protocol (`AGENTS.md §5a`), in order, with real output

| Step | Result |
|---|---|
| 1. `npx supabase db reset` | exit 0, 185 migrations |
| 2. Pass A `npx supabase test db` | **90 files / 1247 assertions, PASS** (was 89/1232) |
| 3. Six HTTP suites | api 29 · lifecycle 107 · journey 74 · **role 80** (was 71) · care 40 · storage 60 = **390**, 0 failed |
| 4. Pass B (no reset, under all six suites' residue) | **90 / 1247, PASS** |
| 5. Smoke `verify_database.sql` | `ALL CHECKS PASSED (75 tables, ...)` |
| 6. Primary's three values, read **FROM** Primary | ledger `28f56ec055d53d42f90f7fef4a7317fd` (185) · functions `393f55466f87d66a7713bdf715bf4080` (254) · structure `5ecc348211a3d9a87f6b1b266f6ea8d4` (3393) |
| 7. `check_database_parity.ps1` | all three **match local**; 2 issues = the manifest's published hashes, then updated |
| 8. Regenerate | `generate-api-contract.ps1` (72 RPCs / 8 views / 71 tables), `ai-map.json` |
| 9. `check_repository_consistency.ps1` | CLEAN |

One deviation worth stating: `repository-all.ps1` regenerated `ai-map.json` and then **cancelled at its interactive commit prompt** (no stdin). Nothing was committed by it; the commit was made deliberately afterwards.

**GUARD-1 recurred exactly as recorded and was handled the recorded way.** `apply_migration` stamped its own version `20260902200119` into Primary's ledger instead of the repository's `202607059600`; normalised before the fingerprint was read, so the ledger hash compares the repository's convention on both sides.

---

## 9. ENVIRONMENT

Local stack `supabase_db_ORVION` healthy. Primary target verified live via `get_project_url` → `https://vrvtsxexkiiiivlkdxzp.supabase.co`, matching `MASTER_INTEGRATION_CATALOG.md §0`, **read from the connector rather than transcribed**. Secondary `brplkqmbzffpxqgkkdzo` never contacted.

---

## 10. CURRENT STATE

185 migrations (latest `202607059600`), identical across repository, local and Primary. Ledger `28f56ec055d53d42f90f7fef4a7317fd`; functions `393f55466f87d66a7713bdf715bf4080` (254); structure `5ecc348211a3d9a87f6b1b266f6ea8d4` (3,393 objects across ten surfaces). 75 tables, 8 reporting views, 72 client RPCs. Suite 90/1247; HTTP 390. Both guards CLEAN. Primary holds zero business rows.

---

## 11. Post-fix discovery — five more classes measured, all clean

Continued into the next slice's discovery after the commit. No further defect found, and the negative results are recorded in `MASTER_EXECUTION_PLAN.md` so they are not re-measured without new evidence (LOCAL RUNTIME, fresh `db reset`):

| Class | Result |
|---|---|
| Direct `DELETE` authority | `authenticated` holds **zero** DELETE on all 75 tables |
| A granted command with no RLS policy | zero |
| `SECURITY DEFINER` hygiene | all 24 reachable by `authenticated` pin `search_path=""`; none executable by `anon` |
| Archive authority | every table with `is_archived` carries `enforce_archive_authority` — no exceptions |
| Reporting views as a read-door | all 8 are `security_invoker`; none exposes a withheld column |

The view check is the one worth recording in detail, because **the first probe was vacuous and was discarded rather than believed.** It selected from `booking_item_profit` against an empty `booking_items` and returned zero rows without error — which looks identical to "no leak" in a transcript and proves nothing (`AGENTS.md §6`). Repeated with a real priced item owned by a **colleague** on all three ownership axes, and with four controls first (the employee holds no VIEW_FINANCIAL_DOCUMENTS; the row is visible to them; the table read is refused 42501; `item_financials` reports `permitted=false`), the view returned the row with `selling_amount 10000` and **`cost_amount` and `profit` NULL**. `app.booking_item_profit` masks money exactly as `item_financials` does. `supplier_outstanding` takes its money from the gated `app.supplier_balance` and never names `credit_limit_amount` at all.

One fixture fault was met and classified as infrastructure rather than a finding: `service_type_code = 'flight'` is not an active catalog value (`flight_ticket` is).

---

## 12. NEXT STEP

**One:** continue the Batch-6 table-by-table audit with the next slice, per `MASTER_EXECUTION_PLAN.md`, which owns the order. The write-without-read class is now closed on all five of its columns, and three further classes (DELETE grants, RLS command coverage, DEFINER hygiene) were measured clean this pass and are recorded there so the next slice does not re-measure them without new evidence.
