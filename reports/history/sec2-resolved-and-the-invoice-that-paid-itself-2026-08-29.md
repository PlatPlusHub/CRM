# ORVION — SEC-2 Was Never One Question, and the Invoice That Paid Itself

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-29
Author: Claude Opus 5
Scope: Migration `202607057100`; test `68_financial_status_capability_test.sql`; the lead-machine
HTTP walk in `verify_lifecycle_branches.ps1`; SEC-2 resolution, FIN-6, FIN-6b, FIN-7, DOC-LC-1,
PAR-1b, API-3's first instalment.
Status: Complete; deployed to Primary and pushed.

**Branch:** `main` · **Start HEAD:** `affcdcb` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Starting state, and an interruption

The previous session ended at a usage limit mid-probe. On resuming, Docker Desktop was down — so the
local stack was unavailable and the failing probe was an environment fault, not a SQL fault. Docker
was restarted, the daemon waited for, and ground truth re-proven before any work: HEAD `affcdcb`,
tree clean, local **and** Primary both at 159 migrations / `28cd2ca6d89881750b5cd2bfb84f9238`.

---

## 2. SEC-2, resolved — and it was never one question

The owner asked that SEC-2 be resolved from evidence before anything else. Searching split it in two,
and only one half was ever a business decision.

### Half one — descriptive fields: INTENTIONAL, derived

Three independent pieces of evidence, none of them an assumption:

1. **The permission catalog names only SPECIFIC mutations.** `EDIT_LOCKED_COST` (one field, after
   lock) and `UPDATE_BOOKING_ITEM_STATUS` (one status). There is no generic `EDIT_<entity>` anywhere.
2. **No `app` function updates a descriptive field.** A scan of every function issuing
   `update public.<table>` returns status changes, ownership changes, money, attribution anchors,
   archive flags and identity merges — and nothing that renames a customer or retitles a booking.
3. **Canon 28 names no such permission.**

So there is no `update_customer`, no `edit_booking`, no `amend_complaint` among the 71 exposed
endpoints. **The PostgREST table endpoint is not a bypass of an intended door — it is the only
door**, and RLS scope is the control ORVION deliberately chose for it. ORVION governs mutation by
*consequence*, not by table.

This is now pinned rather than argued: assertion 7 of `68_...` proves a non-governed column on the
very same row still updates, immediately after four assertions proving the governed ones do not.

### Half two — consequence-bearing fields with no guard: defects

That is what the "business decision" was hiding, and searching for them found one.

---

## 3. FIN-6 — an invoice could be declared paid by anyone who could see it

An `employee` holding `CREATE_INVOICE = f` and `RECORD_PAYMENT = f`, on an invoice they can see
because it belongs to their own booking:

```
mark a 50,000 EGP invoice 'paid' with no payment  ->  SUCCEEDED, status_after = paid
change the invoice AMOUNT                          ->  REFUSED: permission denied: CREATE_INVOICE
```

The second line is what makes the first conclusive: **the guard was present and working and simply
did not cover the status.**

`app.guard_financial_capability` charges capability on UPDATE "only when a MONETARY column changes"
— FIN-3's own words, and correct for `refunds` and `quotation_items`, whose status *is* governed by
`app.enforce_status_transition`. For `invoices` it was not: `app.status_transitions` has **zero** rows
for invoices, and **canon 26 defines no Invoice State Machine at all**. The status was governed by
nothing.

What it buys: declaring a customer's debt settled with no money received.
`reporting.customer_outstanding` and every balance derived from invoice status then agree.

**The fix decides nothing new.** `status_code` and `external_submission_status_code` join the guarded
column list, each costing the permission the table already charges. `external_submission_status_code`
is included on `receipts` too — the Egyptian e-invoicing submission state, where falsely claiming
acceptance by the tax authority is the same class of misstatement one column over (§26).

**Checked before writing, not after breaking:** the only writers of invoice status are
`app.issue_invoice` and `app.record_payment`, and CREATE_INVOICE and RECORD_PAYMENT are held by
exactly the same three roles. Assertion 8 proves finance can still advance an invoice — the assertion
that matters most, since a guard that stopped the employee *and* finance would pass every refusal
above while breaking the business.

---

## 4. FIN-6b — the guard named a column that does not exist

`guard_financial_capability` mapped `receipts` to `array['amount']`. **`public.receipts` has no
`amount` column** — the money lives on the payment it receipts. `to_jsonb(new) ->> 'amount'` is NULL
on both sides, `NULL is distinct from NULL` is false, so `v_changed` never became true: **that
guard's UPDATE branch has been inert for receipts since FIN-3 shipped.**

The root cause is the price of an earlier fix. The `to_jsonb` comparison exists because SPEC-159-A
proved that naming `new.<column>` directly in a multi-table trigger makes plpgsql bind every
referenced field before the CASE picks a branch. Comparing by name fixed that — and removed the
compiler's ability to notice a column that is not there. A wrong name now fails *silently*.

Assertion 11 checks every column in the map against `information_schema`. That is the assertion that
would have caught this on the day it shipped.

---

## 5. Recorded, not guessed

**FIN-7 — canon defines no Invoice State Machine.** Sixteen machines exist in canon 26; there is no
invoice one, yet `invoice_status_code` is a live six-value catalog. FIN-6 governs **who** may change
an invoice's status; it does not govern **which** changes are legal — finance can still move
`draft → paid` directly. Inventing the transitions would be inventing business policy. **BLOCKED**,
with the minimum ruling stated: the legal transitions among the six existing statuses, and whether
`voided` is reachable at all (VOID-1 asks the same question from the columns' side).

**DOC-LC-1 — canon's Document Lifecycle machine was never wired.** Canon defines three transitions
and forbids returning to `active`; `app.status_transitions` has zero rows for `documents`, and
`enforce_archive_authority` fires only when `is_archived` changes, so setting `lifecycle_status_code`
directly walks past it. **OPEN, not blocked** — unlike FIN-7, canon *has* the machine, and the
permissions are derivable from the existing writers (`ARCHIVE_DOCUMENT` for `→ archived`,
`CREATE_DOCUMENT_VERSION` for `→ superseded`). It needs wiring plus proof that `archive_document` and
`add_document_version` still work, which is why it is its own package.

---

## 6. API-3, first instalment: the lead machine over HTTP

`advance_lead` and `convert_lead` were among the 33 endpoints the contract marked as having no HTTP
evidence — and leads are where acquisition becomes revenue, so they were the worst place to be
trusting pgTAP alone. `verify_lifecycle_branches.ps1` grew from 57 to **72** assertions:

create → assign → contact → qualify → quote → negotiate → win → convert.

Three things worth naming:

- **`assigned → contacted` is not `advance_lead`'s to make.** Logging a real interaction is what makes
  a lead contacted, so `record_lead_interaction` owns that transition — one of three the transition
  table permits and `advance_lead`'s own VALUES list deliberately omits (TRANS-1 documented this).
  The first draft of the walk assumed `advance_lead` drove everything and was refused; the script now
  exercises the real division of labour.
- **TRANS-2's handler rule is proven over HTTP for the first time.** A second lead is assigned to the
  owner; the employee is shown to SEE it (canon 28 gives `employee` VIEW_DEPARTMENT_QUEUE) and then
  refused when advancing it. Seeing it first is what makes the refusal mean *the handler rule* rather
  than RLS.
- **ATTR-3 over the wire:** the acquisition source is asserted unchanged after the entire machine.

Coverage moved **38 → 41 of 71**, so API-3 is now 30.

---

## 7. PAR-1b — a correction to yesterday's correction

Deploying `202607057100` produced a PRIMARY FUNCTION DRIFT alarm on `app.document_retention_days`, a
function this package never touched. Narrowing showed local and Primary **swapped** relative to the
previous session.

**The correction:** the API-contract report said Primary's copy had been "restored to the
repository's exact text". It had not. I read that text out of the **local database at a moment when
local had been hand-modified during the session**, and pushed it to Primary — so the fix moved
Primary *away* from the repository while reporting the opposite.

Settled by experiment rather than argument: applying the migration file's own statement produced the
27-character form; a clean `npx supabase db reset` produced the same; the 20-character form existed
only in a hand-modified local. Both environments now hold the repository form, and the function
returns NULL on both — **RET-1's retain-forever default was never at risk on either environment at
any point.**

Root cause worth keeping: **`supabase db reset` is the only thing that makes local equal the
repository.** Applying a migration to local by hand mid-session — normal while iterating — breaks
that equality, and anything read out of local afterwards is not the repository's text. The parity
script's header now says so, and instructs that a drift report be answered by resetting local and
re-reading both sides *before* changing anything on Primary.

---

## 8. Verification

| Axis | Value |
|---|---|
| Migrations | **160** — repository, local, Primary |
| Ledger fingerprint | `9e5fb52c92ce30a8b6d0559be3da7110` — read independently from local and Primary |
| Function surface (230) | `d98abbdd9aea724630f2d97f91a21b08` — identical both sides |
| pgTAP **Pass A** (fresh reset) | **68 files / 816 assertions / 0 failures** |
| pgTAP **Pass B** (post-residue) | **68 files / 816 assertions / 0 failures** |
| End-to-end HTTP | **235/235** — storage 43 · employee 29 · branches 26 · roles 27 · lifecycle 72 · care 38 |
| Smoke | `ALL CHECKS PASSED (75 tables …)` |
| Guards | repository CLEAN · parity CLEAN (ledger, functions, contract freshness) |
| Negative proof | FIN-6 re-run against its own reproduction probe: status refused, invoice stays `issued` at 50,000 |

---

## 9. Classification

**PROVEN DEFECT (fixed)** — FIN-6 (invoice status ungoverned); FIN-6b (a guard mapping a
non-existent column, inert since FIN-3); PAR-1b (method defect in how "the repository's text" was
read).

**RESOLVED from evidence** — SEC-2: descriptive fields INTENTIONAL, consequence-bearing fields were
defects.

**BLOCKED — BUSINESS DECISION (new)** — FIN-7: which invoice status changes are legal. Canon defines
sixteen machines and no invoice one.

**OPEN (derivable, next package)** — DOC-LC-1: wire canon's Document Lifecycle machine into
`app.status_transitions`.

**PROGRESS** — API-3: 33 → 30 uncovered endpoints.

---

## 10. Next logical work

**DOC-LC-1** — it is derivable, bounded, and the last canon-defined machine with no runtime wiring.
Then continue **API-3** (30 left; `create_journal_entry` and `merge_customer_identity` next).

Owner-blocked: DOC-EXP-1, **FIN-7**, SCHED-1, RET-1, RET-2, AUTH-1, FIN-5, SYSADMIN-1, VOID-1,
SPP-3, PH8-2, TRANS-1.
