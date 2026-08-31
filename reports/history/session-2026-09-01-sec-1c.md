# ORVION — SEC-1c: A Row You May Not Create Is A Row You May Not Rewrite

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-09-01
Author: Claude Opus 5
Scope: SEC-1c (`202607059100`) and SUP-1/PD-24 (`202607059200`) — the write and read halves of the
supplier credit question. Tests `85` (14) and `86` (11); 5 HTTP assertions; assertions in tests 57,
67 and 53 superseded with their reasoning. PD-05's deduplication limitation recorded. Both deployed.
Status: Complete. Both migrations DEPLOYED to Primary and reconciled; parity CLEAN at 181.

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

## SUP-1 — the same question's READ half (PD-24, `202607059200`)

`suppliers.credit_limit_amount` — the agency's commercial exposure ceiling — was returned to every
tenant user by one GET, because `suppliers` carries only `tenant_isolation FOR ALL` and PostgREST
serves the table.

**Both halves derived, per the instruction not to assume it belongs behind
VIEW_FINANCIAL_DOCUMENTS merely for looking financial:**

- *Which permission* — `app.supplier_balance`, ORVION's own reader for a supplier's financial
  position, **already raises 42501 without VIEW_FINANCIAL_DOCUMENTS**. The credit limit is the
  ceiling on precisely that balance; guarding the amount owed while publishing the maximum owable
  protects half of one fact.
- *Which mechanism* — `booking_items` **already** withholds `cost_amount` and `commission_rate` from
  `authenticated` by column grant while leaving the row readable, served instead by the gated
  `app.item_financials`. Identical problem, already solved here.

**The first draft was a silent non-fix.** A column-level `revoke select (credit_limit_amount)`
against a role holding TABLE-level SELECT is a no-op — the table grant already covers every column.
The migration reported success while assertions 1 and 5 of test 86 failed. Corrected to revoke the
table grant and re-grant every other column, with the list **derived from `information_schema`** so a
future column is readable by default and only the named exception is withheld.

**Proven at the real door, not inferred:** `GET /suppliers?select=id,name` → 200 with the row;
`select=id,credit_limit_amount` → **403**; `select=*` → **403**. That last is *not* new damage —
`booking_items?select=*` already returns 403 and `booking_items?select=id,selling_amount` returns
200, so clients on such tables must name their columns. The cost belongs to the pattern and is
recorded here rather than discovered by someone later.

**One of my own controls was weak and is fixed:** test 86 first proved "the trainee still sees the
row" with `count(*)`, which needs no column privilege and would have passed even if the table were
closed. It now selects `name`.

## TEST

`85_write_capability_on_update_test.sql` (14) and `86_supplier_credit_visibility_test.sql` (11).
Every refusal is paired with both controls — the actor proven to lack the permission, and the row
proven visible first. Assertions 9–12 of test 85 are the positive controls, including the specific
regression SEC-1b avoided: finance holds ISSUE_BOOKING and not CREATE_BOOKING, and still writes the
booking. Tests 57, 67 and 53 had their superseded assertions rewritten **with their reasoning
preserved**, and 57/67 each gained a companion that fails if the guard stops accepting the
decide/transition permissions — so the union cannot be silently narrowed back.

| Axis | Result |
|---|---|
| Reproducers | all four write probes **REFUSED** (`42501`); the read probe **403** |
| pgTAP **Pass A** | **86 files / 1154 assertions / 0 failures** |
| pgTAP **Pass B** (no reset, post-HTTP residue) | **86 files / 1154 assertions / 0 failures** |
| HTTP, six suites | **371/371** (29 + 102 + 74 + 71 + 38 + 57) |
| Smoke | `ALL CHECKS PASSED (75 tables …)` |
| API contract | regenerated — **72 endpoints, 72 with HTTP evidence** |
| Ledger, repo = local = **Primary** | `181\|67a9e05e43c733594a76dd7e6ce6da31` |
| Function surface | `d9b0dd9cb6dfaa3ac2f38a9cc7601408` (247) |
| Structural surface | `71f87b282df0598ccc100e367e6f7e4c` (3,373 objects) |
| Parity guard | **CLEAN exit 0**, all three Primary values read live FROM Primary |

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

**Both migrations are DEPLOYED and reconciled.** `202607059100` and `202607059200` were applied to
Primary `vrvtsxexkiiiivlkdxzp`, each ledger row normalised from the version `apply_migration` stamps
itself (GUARD-1), and all three fingerprints re-read live **from Primary**: repository = local =
Primary at **181**. The parity guard reports CLEAN exit 0.

**PD-05 recorded, with its limit stated rather than glossed.** `offline_conversions.id` as Google's
`transactionId` guarantees the same local record cannot be counted twice however often ORVION
re-sends it — which is exactly the PH8-1 lease risk, the only duplication ORVION can itself create.
It does **not** deduplicate against a conversion the website tag already reported, because Google
matches on an exact string and a `gen_random_uuid()` will never equal a tag-generated id. Cross-source
dedup needs a *shared* transaction identity minted where the customer transacts; no such column or
upstream producer exists. That is a distinct unopened question, deliberately not designed here.

**Not started this package, and stated rather than implied:** PD-23 (`usage_counters`' zero-producer
gap), ATTR-2's remaining `_by` actor columns, and the care/conversation slice
(`complaints`, `service_requests`, `conversations`, `conversation_messages`, `quotation_items`).
Their write-capability half is now covered by SEC-1c, so the slice starts from a closed write door
rather than an open one.

**Next executable step:** PD-23. Establish, before building anything, which entitlement limits are
enforced today (measured: **none** — `app.plan_allows` / `app.plan_limit` read `feature_entitlements`,
which is seeded with canon 17's numbers, while `usage_counters` has **zero producers**), which writes
should increment, and whether hard-block or allow-and-flag is canonical. Separate the derivable
architecture from the business policy rather than mixing them.
