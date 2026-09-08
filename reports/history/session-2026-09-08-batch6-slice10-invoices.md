# Batch 6 slice 10 — `invoices`: the financial document that could be rewritten after it was issued, and the consequence set nobody had measured

Class: History (immutable)
Date: 2026-09-08
Migration: `202607062000_an_invoice_that_could_be_rewritten_after_it_was_issued.sql`
Test: `supabase/tests/110_invoice_document_integrity_test.sql` — 25 assertions, nine attack classes, one declared `N/A` with a measured reason
Also changed: `72_invoice_allocation_ceiling_test.sql` (four probes re-pointed after a **mechanism substitution** its own run exposed), `87_actor_attribution_second_door_test.sql` (fixture raised as a draft and issued), `scripts/verify_lifecycle_branches.ps1` (+8 HTTP assertions), `MASTER_EXECUTION_PLAN.md` (BOOK-5's fourth occurrence; two more incidental defences; **MECHANISM SUBSTITUTION** added as the inverse case)

---

## 0. HANDOFF

- **INHERITED** — nothing open on this surface. Slice 9 closed its own sibling question and passed
  none forward. `invoices` arrived carrying two *earlier* results that mattered and both were
  re-measured rather than trusted: **FIN-7** (the invoice state machine, registered by
  `202607060200`) and **MEAS-5**'s stated residual — that `invoices.status_code` sits outside the
  class detector. FIN-7's machine is real and correct; MEAS-5's residual is *not* what was wrong here.
- **PROVEN** — seven defects, all reproduced behaviourally before a line was written, five of them
  as an `employee` at `aal2` who holds **no financial permission at all** and can see the invoice
  only because the RLS policy admits them through the booking they own (actor and reach both
  asserted first). **INVOICE-1** (High): `set currency_code = 'USD'` returned UPDATE 1 and
  `app.customer_balance` reported the debt as **50,000 USD** where it had read 50,000 EGP —
  `total_amount` never moved, so no guard fired. **INVOICE-2** (High): `customer_id`, `booking_id`,
  `invoice_number` and `invoice_date` were all writable the same way. **INVOICE-3**:
  `corrects_invoice_id` forgeable. **INVOICE-4**: an invoice could be INSERTed already `paid`, or
  `voided` with no reason and no timestamp. **INVOICE-5**: the total of a **fully paid** invoice raised
  50,000 → 90,000, leaving a gap `app.record_payment` structurally cannot close. **INVOICE-6**: archive
  attribution was caller-supplied on **thirteen** tables. **INVOICE-7**: one invoice renamed
  `INV-2026-abcd` stopped `app.create_invoice` for the whole tenant and year.
- **UNPROVEN** — the `external_submission_*` columns are governed by capability and by nothing else,
  and **zero rows carry a value** because no function writes them. Whether a tax-authority lifecycle
  belongs there is VOID-1's boundary, already decided and not reopened here (§ 6). **ENTRY-1** is
  recorded as a measured class, not as a fix: ten further tables carry a governed transition machine
  and an ungoverned entry.
- **CHANGED** — `202607062000`: one new guard function + trigger, `create_invoice`'s
  numbering scan made total, and `app.enforce_archive_authority` stamping instead of coalescing.
  **No permission was minted, no grant widened or revoked, no RPC added, `app.status_transitions`
  untouched.**
- **DO NOT TOUCH** — assertion 7 of `68_financial_status_capability_test.sql` records as
  *intentional* that the financial guard is column-scoped and not a row freeze. **That principle was
  not overturned and must not be**: `due_date` still updates on an issued invoice, because nothing
  reads it. What slice 10 changed is the *consequence set*, and only where a reader was measured.
  Likewise `72_...` assertions 9/12/17-18 are now deliberately run **session-less**; putting them
  back under an authenticated actor re-creates the substitution described in § 4.
- **REMAINING** — **ENTRY-1** (open, engineering, ten tables); the pre-existing non-blocking list,
  unchanged. Ten owner decisions remain registered and none of them is on this surface.
- **NEXT** — Batch 6 slice 11: **`customers`** (exposure 17), re-measured after this slice, then
  `quotations` and `users` at 15.

---

## 1. Selection, and reading the surface before attacking it

`scripts/batch6_select_target.ps1`, re-run at the start of the session: 67 surfaces still
`NOT-RECORDED`, `invoices` first on **exposure 18**, `customers` 17, `quotations` and `users` 15.
The selector's own banner is honoured — that is a suggestion, not a verdict — so the surface was read
before it was touched: 26 columns, 3 CHECKs, 8 composite FKs, 6 indexes, **10 triggers**, one RLS
policy, 9 `app.status_transitions` rows, and four writers (`app.create_invoice`, `app.issue_invoice`,
`app.record_payment`, `app.void_invoice`).

Two inherited claims were re-measured rather than inherited:

* **FIN-7 / `202607060200`** — the machine exists, the trigger is attached, and the nine rows match
  what the three RPCs actually do. Re-proven, not assumed.
* **TAX-1** — the register already records it as RETRACTED; the live catalog agrees, the
  `tax_submission_status_code` family exists with six values, so `guard_invoice_void`'s
  `external_submission_status_code = 'accepted'` branch is reachable.

## 2. What held — recorded as deliberately as what did not

Measured as the employee described above, on a row proven visible first:

| attack | result | refusing mechanism |
|---|---|---|
| `set total_amount = 1` | 42501 | `app.guard_financial_capability` |
| `set status_code = 'paid'` | 42501 | `app.enforce_status_transition` (FIN-7's machine) |
| `set external_submission_status_code = 'accepted'` | 42501 | `app.guard_financial_capability` |
| `set is_archived = true` | 42501 | `app.enforce_archive_authority` |
| INSERT into another tenant | RLS with-check | the intentional control |
| `set customer_id = <other tenant's>` | FK violation | composite FK (TENANT-1) |
| duplicate `invoice_number` | unique violation | `invoices_tenant_number_key` |
| issue an already-issued invoice | refused | `app.issue_invoice`'s own precondition |

**Concurrency was measured, not reasoned about.** Two overlapping transactions each calling
`app.create_invoice` in the same tenant and year produced `INV-2026-0001` and `INV-2026-0002`, the
second blocking ~2s on `pg_advisory_xact_lock` until the first committed. No duplicate, no gap. That
needs two sessions, so `110_...` declares `CONCURRENCY=N/A` **with this measurement as the reason**
rather than asserting something a single session can always satisfy.

Two hypotheses were killed the same way. A `trainee` cannot reach an invoice at all. And the
`external_submission_*` columns have **no writer anywhere** — a contract for an unbuilt capability,
which is VOID-1's already-decided boundary and not a defect to close by inventing one.

## 3. What did not hold, and why it is one defect

`app.guard_financial_capability` charges CREATE_INVOICE when `total_amount`, `status_code` or
`external_submission_status_code` moves on `invoices` — and nothing else. Assertion 7 of
`68_financial_status_capability_test.sql` pins that as intentional: *"the guard is COLUMN-scoped,
not a row freeze … ORVION governs mutation by consequence, not by table."*

**That principle is right. The consequence set was wrong, and it was wrong by measurement:**

* `currency_code` is read by `app.customer_balance` and `app.customer_exposure_in_limit_currency`.
  An amount is a **pair**; the guard named one half of it. With the invoice already paid in full in
  EGP, flipping the currency left the invoice reading USD while its own `payment_allocations` row
  still read EGP — a document marked `paid` in a currency no money ever arrived in. FA-1's shape
  (`202607061200`) one table over.
* `customer_id` decides whose debt this is and whose credit ceiling it counts against.
* `invoice_number` is the document's identifier in the books — and the vector for INVOICE-7.
* `due_date` has **no reader in any function, view or policy**, so it stays mutable and assertion 7
  stays exactly as written. The rule was extended where evidence reached, and nowhere else.

The repair states an invariant that was already true of every sanctioned path rather than inventing
one. Grep: only `issue_invoice` (status), `record_payment` (status) and `void_invoice` (status +
reason) update this table. Nothing has ever changed an invoice's identity, currency, customer or
booking after the row existed. So identity is **frozen**, `total_amount` moves only while
`old.status_code = 'draft'`, and the entry state is `'draft'` — each derived from a writer, none
from an opinion. Canon 07 ("corrections after approval go through a new event, adjustment or
reversal"), which `app.guard_invoice_void` already quotes, and the `corrects_invoice_id` column
carry the correcting-document route the refusal points at.

**The state question is asked of `old`** — BOOK-5's rule on its fourth table, and the first time it
appears as a design choice rather than a defect. Reading `new.status_code` would have let one
statement set the status back to `draft` and move the total under it.

## 4. The method finding: MECHANISM SUBSTITUTION

The full suite caught something the slice did not go looking for. `72_invoice_allocation_ceiling_test`
assertion 9 shrinks an invoice below what is already allocated and expects `23514` from the deferred
allocation ceiling. After `202607062000`, a **BEFORE** trigger refuses the same statement with the
**same SQLSTATE** for an entirely different reason — so the assertion kept passing while measuring a
different guard, and would have gone on passing if the ceiling were dropped tomorrow. Assertions 12
and 17 (`lives_ok`, and the PAR-4 injection) failed loudly and are what exposed it.

This is the mirror of INCIDENTAL DEFENSE ≠ INTENTIONAL CONTROL: there, an *unintended* mechanism
answers for the intended one; here, a *new* one does. Both are invisible when an assertion pins an
error code instead of a mechanism. Recorded in `MASTER_EXECUTION_PLAN.md` as a standing consequence
of the `AGENTS.md §5b` sweep — **a package that adds a guard must ask which existing assertions now
pass for a different reason** — not as an eighth rule.

The four probes now run on the **platform path**, where the ceiling has no session-less exemption
(assertion 2 of that same file says so explicitly) and is therefore the only thing that can refuse.
The authenticated door is proven separately by `110_...`.

`87_actor_attribution_second_door_test.sql` was the other cross-path hit: its fixture inserted an
invoice directly as `issued`, which INVOICE-4 now refuses. It raises a draft and issues it through the
RPC — two lines, and a more honest fixture.

## 5. Two more incidental defences, named rather than credited

* Detaching the invoice from its booking was refused by an **RLS with-check** — the resulting row
  would have been invisible to that actor. That reads like "you may not move this invoice" and is
  not: re-run onto a *second* booking the same actor owned, the move succeeded.
* `corrects_invoice_id = id` was refused by `invoices_corrects_not_self_check`, a **coherence CHECK**
  about self-reference. Pointing the column at any other invoice was accepted.

Visibility rules and coherence rules are the most convincing impostors, because both refuse while
mentioning the row you were trying to change.

## 6. INVOICE-6, which was never an `invoices` defect

`202607052800`'s own header reads *"ATTRIBUTION IS STAMPED, NOT ASKED FOR. `archived_at` and
`archived_by` are system-generated facts."* The implementation wrote `coalesce(new.archived_by,
v_actor)`, so the caller's value won: a finance manager archived an invoice, recorded a **different
user** as the archiver and dated it **2001-01-01**. IDENT-1's class — a shipped comment that is false.

`app.enforce_archive_authority` serves **thirteen** archivable tables, so the fix went into the one
function they all route through. Cross-path: the two RPCs that set `archived_by` explicitly
(`app.merge_customer_identity`, `app.archive_document`) resolve it with the same
`users`-by-`auth.uid()` lookup `app.current_user_id()` performs, so they write the value they always
wrote; session-less platform paths still early-return. `110_...` proves it on `invoices` **and** on
`customers`, a second table through the same guard, because a repair to a shared function that is
only tested on one table is a per-table repair wearing a shared one's clothes.

## 7. INVOICE-7, and a CHECK constraint that was considered and rejected

`app.create_invoice` allocated the next number with
`max(split_part(invoice_number, '-', 3)::integer)` over `invoice_number like 'INV-<year>-%'`. `like`
admits anything after the second dash. One invoice renamed `INV-2026-abcd` made every subsequent
call raise `invalid input syntax for type integer: "abcd"` — a tenant-wide denial of service
reachable by anyone who could see one invoice. Check-then-act over attacker-controlled text.

Freezing `invoice_number` closes the door the attack came through; it does not make the parser total,
because a `CREATE_INVOICE` holder can still INSERT a malformed number and one day an import will. A
`CHECK (invoice_number ~ '^INV-[0-9]{4}-[0-9]+$')` was the first instinct and is the wrong trade
here: it would also outlaw the `INV-ALLOC-1` / `INV-V96-3` numbers that **nine existing fixtures**
use and no production path produces, turning a one-line repair into a nine-file rewrite for no
behaviour the regex does not already give. The scan now matches the shape the generator produces, so
the cast can never see anything else. `110_...` 19-20 plants the malformed row and then requires the
sequence to carry on correctly past it.

## 8. ENTRY-1 — the next recurrence, recorded rather than fixed

INVOICE-4 is LEAD-2's shape, and two instances make a class. Measured: `app.enforce_status_transition`
is attached to **twelve** tables and is `before update` on all of them; exactly **two** —
`leads` and `invoices`, the two Batch-6 slices that reached them — carry an entry-state guard. Ten
tables have a governed transition machine and an ungoverned entry.

Deliberately not fixed generically: `app.status_transitions` records `from_status -> to_status` and
has no notion of a first state, and each table's entry state has to be read off its own creating RPC.
Inventing a shared rule from two samples would be inventing policy for ten tables nobody has read.
Registered as **ENTRY-1** with its trigger — closed per surface as Batch 6 reaches each table, or
promoted into the shared trigger if a third slice finds itself writing the same guard.

## 9. Verification

| step | result |
|---|---|
| `npx supabase db reset` | 209 migrations applied clean |
| pgTAP Pass A | **110 files / 1739 assertions — all pass** |
| six HTTP suites | **445 / 0** (29 · 122 · 74 · 120 · 40 · 60) |
| pgTAP Pass B (no reset) | **110 / 1739 — identical to Pass A** |
| smoke | `ALL CHECKS PASSED (77 tables)` |
| repository consistency | `CLEAN` (Checks 1–25) |
| database parity | `CLEAN` — local proven; Primary ledger, functions and structure proven |
| Primary `vrvtsxexkiiiivlkdxzp` | 209 / `202607062000`; ledger `102a08f0009493b58d2583ae28a0c17c`, functions `d0b08965d902ee9d9bc0bbb4c5d10745`/280, structure `34add22404df8f87411f295bf72c069c`/3568 — **all ten sub-surfaces identical**, all three values READ FROM Primary (GUARD-1) |

The structural surface moved 3,566 → 3,568: exactly this migration's one function and one trigger.
No constraint, no column, no grant, no policy, no index and no `status_transitions` row changed.

## 10. Current state

Repository, local stack and Primary all at **209 migrations**, latest `202607062000`. Batch 6
coverage **11 of 77**, all eleven `ADVERSARIAL`; Batch 6 is **NOT complete**.

## 11. Next step

**Batch 6 slice 11 — `customers`** (exposure 17), the measured top of the remaining 66. It is also
the table INVOICE-2 kept pointing at: `customer_id` decides whose debt an invoice is, and the customer
side of that relationship has not been audited.
