# ORVION — The Branches Nobody Had Walked, and the Trainee's First Morning

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-28
Author: Claude Opus 5
Scope: `scripts/verify_lifecycle_branches.ps1` (57 HTTP assertions). No migration — this package
executes the system as it stands and reports what it finds.
Status: Complete; pushed.

**Branch:** `main` · **Start HEAD:** `a7cf7b1` · **Environment:** local stack (the CRM over real HTTP).

---

## 1. What was unproven, and now is not

The previous two reports listed the same UNPROVEN block each time: the trainee's full journey, and
seven lifecycle branches. All eight are now executed over real HTTP with real JWTs.

| branch | result |
|---|---|
| trainee full journey | **proven** — 8 assertions |
| quotation rejected | **proven** — `sent → rejected` |
| quotation revised | **proven** — `rejected → draft`, re-priced on the *same* quotation, re-sent |
| quotation expired | **proven** — `sent → expired`, and `expired → draft` when the customer returns |
| booking modified | **proven** — `issued → reissue → issued`, finance only |
| partial payment | **proven** — 10,000 then 15,000 against a 25,000 invoice, allocated exactly |
| supplier failure | **proven** — service request parked on `awaiting_supplier`, line cancelled, refund completed |
| document expiry | **proven** for the read path; **DOC-EXP-1 found** on the notify path |
| repeat booking | **proven** — same customer, second booking, both in the 360 timeline |

**57 passed, 0 failed.** Total end-to-end HTTP coverage rises from **118 to 175** across five scripts.

---

## 2. The trainee, which is mostly a set of refusals — and that is the point

A trainee holds exactly two permissions: `VIEW_ASSIGNED_LEADS`, `VIEW_ASSIGNED_TASKS`. A journey made
of refusals is worthless unless each refusal is demonstrably about **capability** rather than a
broken session or an unreachable row, so the file opens with a positive control on the same query
that later denies:

- the trainee **sees their assigned lead** — session, token, tenant resolution and RLS all work;
- the trainee **does not see the colleague's lead** — proven on the *same* result set, so this is
  scope, measured against a row that demonstrably exists;
- they cannot create a customer, a lead, a quotation, or a task;
- they see **no** financial data;
- and, at the end, they still see the customer master row but none of its history.

That last pair is the shape canon 05 requires: a customer is not branch-scoped, but their *activity*
is.

### The one thing a trainee CAN write, pinned deliberately

A trainee **can log a lead interaction**. That is asserted as a **pass**, not hidden, because it is
the exact behaviour of SEC-1's last open table: `app.record_lead_interaction` is SECURITY INVOKER,
granted to `authenticated`, and authorizes nothing — so the RPC and direct DML agree, and there is no
bypass to close, only an undecided question about what logging should cost. Pinning the current
behaviour is how the next session notices if it changes by accident.

---

## 3. Findings

### DOC-EXP-1 — an expiring passport tells nobody

`app.expiring_documents(p_within_days)` works correctly and is proven three ways: it finds a passport
expiring in 10 days, excludes one expiring in 400, and excludes the 10-day one when asked for a
5-day window — so the parameter is honoured rather than decorative.

But the `document_expiry` notification type exists in the catalog and **nothing produces it**. The
only writer of `notifications` in the entire database is `app.process_lead_sla`. An agency therefore
learns about an expiring passport only if someone remembers to open the report.

Recorded as **DOC-EXP-1**. Not fixed here: who should be notified, how far ahead, and how often are
business decisions, and canon's SLA machinery answers none of them for documents.

### Over-payment is refused — pinned as observed, not as a wish

A third payment of 999,999 against an already-settled 25,000 invoice is **refused**. The assertion
was written to record whatever ORVION actually does, with a second assertion guaranteeing that
whatever happened did not *reduce* what was already allocated. The behaviour is correct; it is now
also pinned.

### A guard doing its job, found by tripping over it

`upload_document` **refuses a passport linked to a booking**: a passport belongs to a person, and the
function enforces `p_link_target_type = 'passenger'` for that document type. My first run failed
here. The script now asserts the refusal as well as the success, so the rule is covered rather than
merely obeyed.

---

## 4. My own errors, and one that mattered beyond this file

The first run was 42/7. Every one of the seven was mine, not ORVION's: invented catalog values
(`call` for `phone_call`, `complaint_followup`, `service_not_delivered`), an omitted required
argument (`p_cancellation_reason_code`, which ORVION correctly demands when cancelling), and the
passport link-target rule above. All corrected by reading the catalogs and the function.

The one worth recording is different in kind: my fixture used the tenant slug `lifecycle-travel`,
which **`32_lifecycle_transition_test.sql` already uses**. pgTAP files roll back, so tests never
collide with each other; the HTTP scripts do **not** roll back, so a script slug must be unique
against every *test* slug too. It surfaced only in the order-independent regime — running pgTAP after
the HTTP suites — which is the regime introduced one package earlier for exactly this reason. All
five scripts' slugs were then checked against all 58 test files: no other collision exists.

---

## 5. Verification

| Axis | Value |
|---|---|
| Migrations | 150 — repository, local, Primary; fingerprint `2f94900a67e5bb589b8a3c7303339c3f` |
| pgTAP | **58 files / 672 assertions / 0 failures**, re-run **after all five HTTP suites' residue** |
| End-to-end HTTP | **175/175** — storage 36 · employee 29 · branches 26 · roles 27 · **lifecycle 57** |
| Smoke | `ALL CHECKS PASSED` |
| Guards | repository CLEAN · parity CLEAN |

No migration in this package, so parity is unchanged by construction and re-proven anyway.

---

## 6. Classification

**PROVEN** — all eight previously-unproven journeys; the trainee's capability boundary with a
positive control on the same query; the quotation's three endings and their revival paths; the
approve/issue/reissue authority split; deposit-then-balance payment allocation; the supplier-failure
chain end to end; the expiry window as a real filter; the returning customer.

**UNPROVEN** — nothing from the previous report's list remains.

**FAILED** — none.

**BLOCKED** — **DOC-EXP-1** (new) · SEC-1 (`lead_interactions`) · AUTH-1 · FIN-5 · SYSADMIN-1 ·
TRANS-1 · TASK-3 · SCHED-1 · RET-1, RET-2, ORPH-1, LEAD-2, PLAN-1, BLOCKED-4/5, CANON-26-1 ·
DEL-1 (partial) · PP-1 · LIC-1 · EVT-2 · RBAC-2 · PERM-1.

**INTENTIONAL** — a trainee may log a lead interaction (pinned, pending SEC-1's last decision);
over-payment refused; passports linked only to passengers.

---

## 7. Next logical work

**TRANS-1** — transition authority duplicated between the `advance_*` functions and
`app.status_transitions` — and **SCHED-1** — nothing invokes the storage executor on a schedule.
Both are investigations before they are changes.
