# ORVION — Session 2026-08-29: From the API Contract to the Invoice That Paid Itself

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-29
Author: Claude Opus 5
Scope: The whole session, across a usage-limit interruption — the owner's ten recommendations, the
API Capability Contract, SEC-2's resolution, FIN-6/FIN-6b, API-3's first instalment, and three
corrections to my own earlier claims.
Commits: `affcdcb` (before the limit) · `0698033` (after) · settings-only change, not committed
(gitignored).
Status: Complete; both halves deployed to Primary, pushed and remotely verified.

---

## 1. Why this report exists

The session was interrupted by a usage limit part-way through the SEC-2 investigation, and resumed
later. Two package reports already exist —
`the-api-capability-contract-2026-08-29.md` and
`sec2-resolved-and-the-invoice-that-paid-itself-2026-08-29.md` — but neither spans the interruption.
This is the session-level record: what was in flight when it stopped, what the environment looked
like on resuming, and the single through-line that connects both halves.

**The through-line: three of this session's findings were defects in the things that measure, not in
the things measured.** SEC-1b's ceiling counted UPDATE-only triggers as INSERT protection. A guard
mapped a column that does not exist and so guarded nothing for months. And twice I read "the
repository's text" out of a database that was not the repository. The programme's standing lesson —
*a guard written against the first instance takes that instance's shape* — held again, and this time
two of the three instances were mine.

---

## 2. Starting state (re-proven, not carried forward)

| Axis | Evidence |
|---|---|
| git | HEAD = `origin/main` = `d4438a8`, tree clean |
| Repo / local / Primary | 159 migrations, `28cd2ca6d89881750b5cd2bfb84f9238` on all three |
| Function surface | `1c63f2545d2452cece517e324c5b25c7` (230), identical both sides |
| Suite | 67 files / 805 assertions · HTTP 220/220 |

---

## 3. First half — the owner's ten recommendations, and the contract

### The evaluation

Nine ACCEPT, one ACCEPT-with-finding. **None changed the execution order.** One refined it, and that
refinement became the package.

**The refinement.** `authenticated` holds SELECT on 69 tables, INSERT on 54, UPDATE on 54, DELETE on
**none** — and PostgREST serves tables directly. `POST /rest/v1/complaints` is exactly as reachable
from a browser as `POST /rest/v1/rpc/create_complaint`. A contract listing only the 71 RPC endpoints
would have documented the smaller half of the door, and the larger half is where SEC-1b lived.

Two recommendations produced concrete findings rather than agreement:

- **#3 (don't prematurely build WhatsApp/AI).** The data model is ready and this was verified, not
  assumed: `external_conversation_id` exists, `customer_id` / `owner_user_id` / `sender_user_id` are
  all nullable, `whatsapp` is in both catalogs, and `capture_attribution_click` is already granted to
  `orvion_integration`. What is missing is a **door**: all three conversation RPCs are
  `authenticated`-only and `start_conversation` demands a branch placement, so an inbound-first
  message would require impersonating an employee JWT. Recorded as **CONV-3, DEFER** — one function,
  not a redesign, with `capture_attribution_click` as the in-house precedent.
- **#6 (don't let SEC-2 block the contract).** Agreed, and bounded by measurement rather than
  argument — see §5.

### MASTER_API_CONTRACT.md

Generated from `pg_catalog` and `app.status_transitions`, never hand-written, and kept honest by a
new **Check L3** in `check_database_parity.ps1` that regenerates and diffs it. **Proven in both
directions**: a tampered line produced `CONTRACT STALE`; regenerating cleared it.

**Two defects in the generator, caught before it shipped.** It picked the permission by first-match
`CASE`, so `advance_lead` reported only `CLOSE_LEAD` and silently dropped the TRANS-2 handler rule —
*a contract that understates authority is worse than none*, and it is SEC-1b's own shape written into
the tool built to expose that class. And the HTTP-coverage column reported **1** endpoint covered
when the true figure was **38**, because the suites call through a `Rpc $VAR 'name'` helper.

**API-3 recorded:** 33 of 71 endpoints had no HTTP evidence — measured from the suites themselves.

---

## 4. The interruption

The session stopped at a usage limit mid-probe, during the SEC-2 investigation. In flight at that
moment: the invoice-status probe, which had just failed — on an **invalid UUID** (`…0000i1`; `i` is
not a hex digit), not on anything meaningful.

On resuming, the local stack was unreachable. **Docker Desktop was down**, so the failure was an
environment fault, not a SQL fault. Docker was restarted, the daemon polled until up, and ground
truth re-proven before touching anything: Primary unchanged at 159 / `28cd2ca6…`, local restored to
the same, HEAD `affcdcb`, tree clean.

Recording this because "the probe failed" and "the database was not running" look identical in a
transcript, and only one of them is a finding.

---

## 5. Second half — SEC-2 resolved, and what it was hiding

### SEC-2 was never one question

**Descriptive fields → INTENTIONAL**, derived from three independent facts:

1. The permission catalog names only *specific* mutations — `EDIT_LOCKED_COST` (one field, after
   lock), `UPDATE_BOOKING_ITEM_STATUS` (one status) — and no generic `EDIT_<entity>`.
2. Every `app` function issuing `update public.<table>` changes status, ownership, money,
   attribution, archive flags or identity merges. **Not one updates a descriptive field.**
3. Canon 28 names no such permission.

There is no `update_customer` among the 71 endpoints, so the table endpoint is **not a bypass of an
intended door — it is the door**, and RLS scope is the control ORVION chose. Reproduced and bounded:
a `trainee` renamed the lead assigned to them (succeeded) and could not see or edit a colleague-owned
complaint (0 rows, `UPDATE 0`).

**Consequence-bearing fields with no guard → defects.** That is what the "business decision" was
hiding.

### FIN-6

```
employee (CREATE_INVOICE = f, RECORD_PAYMENT = f)
  mark a 50,000 EGP invoice 'paid' with no payment  ->  SUCCEEDED
  change the invoice AMOUNT                          ->  REFUSED: permission denied
```

The second line is what made it conclusive: the guard was present and working and simply did not
cover the status. `guard_financial_capability` charges on UPDATE only for **monetary** columns —
right for `refunds` and `quotation_items`, whose status is governed by canon machines; wrong for
`invoices`, where `app.status_transitions` has zero rows and **canon defines no Invoice State
Machine at all**. A customer's debt could be declared settled with no money received, and
`reporting.customer_outstanding` would agree.

Checked *before* writing: `CREATE_INVOICE` and `RECORD_PAYMENT` are held by the same three roles, and
an assertion proves finance can still advance an invoice — the assertion that matters most, since a
guard stopping both would pass every refusal while breaking the business.

### FIN-6b

The same guard mapped `receipts` to `array['amount']`, and **`receipts` has no `amount` column** —
the money lives on the payment. `NULL is distinct from NULL` is false, so that UPDATE branch **has
been inert since FIN-3 shipped**. The cause is the price of an earlier fix: the `to_jsonb` comparison
exists because SPEC-159-A proved direct `new.<column>` references bind across every branch — and it
removed the compiler's ability to notice a column that is not there. A class assertion now checks
every mapped column against `information_schema`.

---

## 6. API-3, first instalment

The lead machine — where acquisition becomes revenue — had no HTTP walk.
`verify_lifecycle_branches.ps1` grew 57 → **72**: create → assign → contact → qualify → quote →
negotiate → win → convert.

Three things it establishes:

- **`assigned → contacted` is not `advance_lead`'s to make.** Logging a real interaction is what makes
  a lead contacted, so `record_lead_interaction` owns it — one of three transitions the table permits
  and `advance_lead`'s VALUES list deliberately omits. My first draft assumed otherwise and was
  refused; the walk now exercises the real division of labour.
- **TRANS-2's handler rule proven over HTTP for the first time** — the employee is shown to *see* a
  colleague's lead, then refused when advancing it. Seeing it first is what makes the refusal mean
  the handler rule rather than RLS.
- **ATTR-3 over the wire** — the acquisition source survives the entire machine.

Coverage 38 → **41 of 71**; API-3 is now 30.

---

## 7. Three corrections to my own earlier claims

Recorded because hiding them would be the worse failure.

1. **PAR-1a (first half).** The 2026-08-28 report claimed all 228 functions byte-identical at
   `4821a18a…`. That comparison used `'--[^\n]*'`, and inside a POSIX bracket expression the
   backslash is not an escape — `[^\n]` means *"not a backslash and not the letter n"*. The claim
   held only under a weaker normalization.
2. **PAR-1b (second half).** The API-contract report said Primary's `document_retention_days` was
   "restored to the repository's exact text". It was not — I read that text out of a **local database
   I had hand-modified mid-session** and pushed it to Primary, moving Primary *away* from the
   repository while reporting the opposite. Settled by experiment: the migration file's own statement
   and a clean `db reset` both produce the 27-character form, both environments now hold it, and the
   function returns NULL on both — **RET-1's retain-forever default was never at risk on either
   environment at any point.** `supabase db reset` is the only thing that makes local equal the
   repository; the parity script's header now says so.
3. **The broken update-RPC scan.** An early SEC-2 query used `\b` after a group alternation and
   returned zero rows, which would have supported the false conclusion "ORVION has no update RPCs at
   all". Caught by re-running it loosely before drawing anything from it.

---

## 8. Verification (end state)

| Axis | Value |
|---|---|
| Migrations | **160** — repository, local, Primary |
| Ledger fingerprint | `9e5fb52c92ce30a8b6d0559be3da7110` — read independently from each |
| Function surface (230) | `d98abbdd9aea724630f2d97f91a21b08` — identical both sides |
| pgTAP **Pass A** (fresh reset) | **68 files / 816 assertions / 0 failures** |
| pgTAP **Pass B** (post-residue) | **68 files / 816 assertions / 0 failures** |
| End-to-end HTTP | **235/235** — storage 43 · employee 29 · branches 26 · roles 27 · lifecycle 72 · care 38 |
| Smoke | `ALL CHECKS PASSED (75 tables …)` |
| Guards | repository CLEAN · parity CLEAN on all three axes (ledger, functions, contract freshness) |
| Remote | `gh api` = local HEAD = `origin/main` = `0698033`, tree clean |

Session movement: 159 → 160 migrations · 67 → 68 test files · 805 → 816 assertions · 220 → 235 HTTP.

---

## 9. Ledger of findings

**FIXED** — FIN-6 (invoice status ungoverned), FIN-6b (a guard mapping a non-existent column, inert
since FIN-3), PAR-1a and PAR-1b (both method defects in how parity was measured and reported).

**RESOLVED from evidence** — SEC-2, split into an intentional half and a defect half.

**DELIVERED** — API-2, the generated capability contract and its freshness guard.

**BLOCKED — BUSINESS DECISION (new)** — **FIN-7**: canon defines sixteen state machines and no
invoice one, so *which* invoice status changes are legal is undecided. Minimum ruling: the legal
transitions among the six existing statuses, and whether `voided` is reachable (VOID-1 asks the same
from the columns' side).

**OPEN (derivable, next)** — **DOC-LC-1**: canon's Document Lifecycle machine was never wired into
`app.status_transitions`; permissions derivable from the existing writers. **API-3**: 30 endpoints
still without HTTP evidence. **CONV-3**: no session-less inbound conversation door (integration
phase).

**Unchanged owner-blocked set** — DOC-EXP-1, SCHED-1, RET-1, RET-2, AUTH-1, FIN-5, SYSADMIN-1,
VOID-1, SPP-3, PH8-2, TRANS-1.

---

## 10. Governance repair made while writing this

`reports/README.md` states its own rule: *"Whoever writes the next session report updates this row in
the same commit — an unlinked report is invisible to the boot sequence, which is the one job this
pointer has."* The pointer was **five reports stale**, and no guard noticed: Check 1 verifies that
references resolve, not that the pointer is current.

**GOV-1**, fixed here: the pointer is updated, and `check_repository_consistency.ps1` gains **Check
10** — the file named in README's *Latest session report* line must be the same file named in the
manifest's `Narrative:` field. Both are maintained every package, so disagreement means one was
forgotten. Proven in both directions before shipping.

---

## 11. Next logical work

**DOC-LC-1** — derivable, bounded, and the last canon-defined state machine with no runtime wiring.
Then **API-3** endpoint by endpoint (`create_journal_entry`, `merge_customer_identity` next).

Nothing in this session changed the execution order the owner proposed.
