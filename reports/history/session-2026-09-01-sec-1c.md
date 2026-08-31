# ORVION — SEC-1c: A Row You May Not Create Is A Row You May Not Rewrite

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-01
Author: Claude Opus 5
Scope: SEC-1c, owner-approved as the first engineering action. Migration `202607059100`; test
`85_write_capability_on_update_test.sql` (14); assertions in tests 57 and 67 superseded with their
reasoning. **Not deployed to Primary — awaiting explicit approval per the owner's standing rule.**
Status: Implemented and verified on local; deployment pending.

**Branch:** `main` · **Start HEAD:** `0eadf79` · **Environment:** local only this package.

---

## FOUND

`app.guard_write_capability` was attached **`BEFORE INSERT` only** on thirteen tables. Found by
reading why `suppliers.credit_limit_amount` is visible to everyone (PD-24) and discovering that
`suppliers` has one policy (`tenant_isolation FOR ALL`) and one capability trigger that fires on
INSERT alone — then asking the class question instead of stopping at the instance.

Measured against RLS, the thirteen split three ways:

| | tables | UPDATE `WITH CHECK` |
|---|---|---|
| ungoverned | customers, passengers, suppliers, customer_notes | tenant isolation and nothing else |
| read-scope-only | bookings, complaints, conversations, documents, leads, quotations, service_requests, tasks | names only **VIEW_*** permissions plus ownership — RLS-1, merged into SEC-1 |
| correct | approval_requests | genuine decide permissions |

**This is the exact mirror of SEC-1b**, which found the ceiling crediting tables for an UPDATE-only
trigger and attached twelve of them on INSERT. Nobody then asked the inverse question about the
tables SEC-1b had just attached. A guard written to close one direction was attached in one
direction.

## PROVED

On a clean reset at 179, as a `trainee`, inside a rolled-back transaction:

```
CONTROL  CREATE_CUSTOMER=f CREATE_PASSENGER=f MANAGE_SUPPLIERS=f VIEW_FINANCIAL_DOCUMENTS=f
CONTROL  rows visible first: customers=1 passengers=1 suppliers=1 (credit 1000)
NEGATIVE INSERT customers            -> REFUSED "one of CREATE_CUSTOMER is required"
PROBE    UPDATE customers.full_name  -> UPDATE 1
PROBE    UPDATE passengers.full_name -> UPDATE 1
PROBE    UPDATE suppliers.credit_limit_amount -> UPDATE 1   1000 -> 999999
```

The refused INSERT **in the same session on the same table** is what makes this non-vacuous: it
proves the actor is genuinely unprivileged, so the difference is INSERT vs UPDATE and not the
fixture.

## ROOT CAUSE

SEC-1b faced a real constraint — `finance_manager` holds ISSUE/CANCEL/REFUND/REISSUE_BOOKING and
**not** CREATE_BOOKING, so charging the insert permission on UPDATE would have broken finance. It
resolved that by not attaching on UPDATE at all, which avoided the breakage and left the path
unguarded. Two tests then pinned that shape as deliberate (`57` #11, `67` #9). The premise was
right; the conclusion drawn from it was the defect.

## DECISION — derived, not chosen

**Canon 28 defines no general edit permission.** Repository-wide, the only mutation-shaped
permissions canon names beyond `CREATE_*` are `EDIT_LOCKED_COST` and `UPDATE_BOOKING_ITEM_STATUS`,
both narrow and field/state-specific. Demanding an `EDIT_*` canon never defined would be inventing
business policy.

Two existing facts settled it instead:

1. **Twelve tables already carry this guard as `INSERT OR UPDATE`** with the same object-class
   permission for both. The rule already exists here; thirteen tables were simply missed.
2. **`app.status_transitions.permission_key`** already records, per table, which permission may
   legally change that object's state — canon-encoded data, not a judgement.

**UPDATE set = object-class permission ∪ that table's transition permissions.** `v_perms` was
already a `text[]` evaluated as "any of", so no new mechanism was needed.

## FIX

`202607059100`. Checked against real role holdings *before* writing, because "verify no unrelated
capability was removed" is the point: the union keeps `advance_booking` (ISSUE_BOOKING),
`archive_document` (ARCHIVE_DOCUMENT), `add_document_version` (CREATE_DOCUMENT_VERSION) and FIN-2's
`review_finance_approval` (APPROVE_FINANCE) working. A blanket CREATE-only rule was rejected on that
evidence, not on taste. `payment_proof` documents keep their strict `MANAGE_TENANT_SETTINGS` on both
paths, preserving PP-4. The session-less early return is untouched.

**Two of my own errors are recorded because both are the lesson:**

- The first draft wrote `new.document_type_code` inside a condition evaluated for *every* table —
  the exact trap the file's own comment describes. PL/pgSQL resolves a record field against the real
  record type regardless of branch, so it raised on `suppliers`. Fixed with a boolean set inside the
  `documents` branch.
- **One authority is a relationship, not a permission, and only HTTP caught it.**
  `app.record_lead_interaction` reads *"the assigned handler, OR ASSIGN_LEAD"* — so a trainee
  assigned a lead may log a call while holding none of the lead permissions. The first draft removed
  that. **pgTAP was entirely green (85 files / 1143 assertions); `verify_lifecycle_branches.ps1`
  failed.** That is the standing argument for testing both doors rather than a formality. The rule
  is now mirrored verbatim from the RPC, and it does not reopen the defect because the reproduced
  trainee was assigned nothing.

## TEST

`85_write_capability_on_update_test.sql` (14). Every refusal is paired with both controls — the
actor proven to lack the permission, and the row proven visible first. Assertions 9–12 are the
positive controls, including the specific regression SEC-1b avoided: finance holds ISSUE_BOOKING and
not CREATE_BOOKING, and still writes the booking. Tests 57 and 67 had their superseded assertions
rewritten **with their reasoning preserved**, and each gained a companion that fails if the guard
stops accepting the decide/transition permissions — so the union cannot be silently narrowed back.

| Axis | Result |
|---|---|
| Reproducers | all four now **REFUSED** (`42501`), controls intact |
| pgTAP **Pass A** | **85 files / 1143 assertions / 0 failures** |
| pgTAP **Pass B** (no reset, post-HTTP residue) | **85 files / 1143 assertions / 0 failures** |
| HTTP, six suites | **366/366** (29 + 102 + 74 + 66 + 38 + 57) |
| Smoke | `ALL CHECKS PASSED (75 tables …)` |
| API contract | regenerated — 71 of 71 endpoints with HTTP evidence |
| Local ledger | `180\|1b9b3c585513fc40897fe10e68e0bf5f` |
| Local structural surface | `0b4ffdeff4299cf78ea0d231657014e5` (3,372 objects) |

## RE-SCAN

The class detector re-run across every table `authenticated` may UPDATE: **13 → 4**, then **4 → 0**
after attacking the detector.

Three of the four are `otp_challenges`, `totp_enrollments`, `trusted_devices` — the canon-34 Human
Identity tables, SEC-1's declared intentional residue, reaffirmed by PD-10/AUTH-1.

The fourth, `lead_interactions`, is a **false positive of my own detector** (**MEAS-3**): it *is*
guarded, by `guard_lead_interaction_authority` → `app.require_lead_handler(...)`. Capability is
enforced through one level of helper indirection the regex could not follow — MEAS-1 again, a
detector whose description outruns its measurement. Recorded rather than dropped, because any future
scan written this way inherits the blind spot.

## REMAINING

**The migration is NOT deployed to Primary.** The owner's standing rule for this directive is "no
Primary writes unless explicitly approved", and that outranks the "no undeployed migrations"
invariant, so repository and local sit at **180** while Primary remains at **179**
(`1f64a99ca835e0a54a222944c1aadcf5`). This is a deliberate, stated divergence, not drift. The parity
guard will correctly report DRIFT until the deployment is approved and applied.

Next: the remaining approved engineering items whose prerequisites are satisfied — PD-05's
dedup-identifier limitation record, PD-23's `usage_counters` zero-producer investigation, and PD-24's
supplier-credit *visibility* question (its UPDATE half is closed by this package).
