# ORVION — Phase C: The Ledger Was Guarded and the Cash Was Not

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-28
Author: Claude Opus 5
Scope: Migration `202607055900`, test `56_financial_write_capability_test.sql`, `10` (ceilings
tightened), `38` (fixture corrected). Produces the full SEC-1 per-table inventory the directive
required, then fixes **FIN-3** and **FIN-4** — the actionable defects that inventory exposed.
Status: Complete; deployed to Primary and pushed.

**Branch:** `main` · **Start HEAD:** `f07e3a0` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Objective

The directive's §2–3: do **not** guess an authorization architecture for SEC-1. Produce a systematic
inventory first, then continue every independent engineering task rather than stalling on the
decision.

---

## 2. Starting state, re-proven live

| Axis | Evidence |
|---|---|
| GitHub | `origin/main` = `f07e3a0860bc…` = local HEAD; tree clean |
| Repository | 147 migrations, 55 test files |
| Local + Primary | 147 migrations, fingerprint `538c03737d2d1f03553d93c1d5a82785` |

---

## 3. The SEC-1 inventory — and a correction to my own last report

**Architectural shape, measured:**

| | count |
|---|---|
| `app` functions, `SECURITY DEFINER` | 36 |
| `app` functions, `SECURITY INVOKER` | 81 |
| …of which write tables directly | **56** |
| `authenticated` INSERT / UPDATE / DELETE | 59 / 59 / **0** |

That 56 is the decisive number for **Option A** (revoke `authenticated`'s table writes): those
functions are `SECURITY INVOKER` and depend on the caller's own table grants, so revoking the grants
means converting **56 functions** to `SECURITY DEFINER` — a change to the entire authorization model,
not a configuration tweak.

**Enforcement shape — and where I was wrong.** My previous report said "40 tables have no capability
check anywhere". That number counted **triggers only**. Re-measured including RLS `WITH CHECK`
expressions that reference `has_permission`:

| enforcement | tables |
|---|---|
| by capability trigger | 19 |
| by policy `WITH CHECK` naming a permission | 30 |
| either | 36 |
| **neither** | **23** |

So the exposure was **overstated at 40; the honest figure was 23.** Recorded here because the
previous commit message and report carry the wrong number.

**Then a second, worse discovery: "names a permission" is not "requires the right one."** Reading the
policies rather than counting them:

```
payments      with check: tenant AND ( has_permission('VIEW_FINANCIAL_DOCUMENTS')
                                       OR booking is visible OR booking item is visible )
receipts      with check: tenant AND ( has_permission('VIEW_FINANCIAL_DOCUMENTS')
                                       OR the payment is visible )
refunds, invoices, payment_allocations: the same shape.
```

The permission named is a **read** permission, sitting in an `OR` with a pure visibility test. The
effective rule was **"you may write money about anything you can see"** — the RLS-1 pattern (a read
predicate authorizing writes) recurring in the one family where it costs most. So those five tables
were counted as guarded by my own corrected metric and were not guarded at all.

---

## 4. FIN-3 — reproduced, then fixed

An `employee` (`RECORD_PAYMENT = false`, `RECORD_REFUND = false`), against a booking they own:

```
insert into public.payments (..., amount, ...) values (..., 999999, 'EGP', 'cash', now());
FORGED PAYMENT ROWS BY EMPLOYEE WITHOUT RECORD_PAYMENT: 1
```

`app.record_payment` charges `RECORD_PAYMENT`, held by ceo, finance_manager and owner only.

**ORVION already knew the right pattern**, which is what makes this an omission rather than a design
choice: `journal_entries` and `journal_entry_lines` require `has_permission('CREATE_JOURNAL_ENTRY')`
in `WITH CHECK`. **The ledger was guarded and the cash was not.**

**The fix invents nothing.** Each table is charged exactly the permission its own RPC already
charges, read out of the functions:

| table | permission | RPC it comes from |
|---|---|---|
| `payments`, `payment_allocations` | `RECORD_PAYMENT` | `record_payment`, `record_supplier_payment` |
| `receipts` | `CREATE_RECEIPT` | `issue_receipt` |
| `refunds` | `RECORD_REFUND` | `record_refund` |
| `invoices` | `CREATE_INVOICE` | `create_invoice` |
| `quotation_items` | `CREATE_QUOTATION` | `add_quotation_item` |

No permission invented, no role gains anything, every RPC unchanged — it charges the same permission
a moment before the trigger does. A trigger rather than a policy amendment because these are `for
ALL` policies whose long expressions are shared between `USING` and `WITH CHECK`; retranscribing them
is how PP-2 lost a branch. Scope: INSERT always, UPDATE only when a monetary column actually changes,
so status advances and verification stamps keep the authority they already had. System paths exempt
from the *check*, never from the *record*.

---

## 5. FIN-4 — an approval request could name someone else as its requester

`approval_requests.scope_insert` checked only `tenant_id`. `requested_by` was an ordinary
caller-supplied column, so any tenant user could open a request and attribute it to a colleague — and
that record is the evidence of who asked for the exception.

Fixed in WP-00's shape and deliberately **not** with a permission: `requested_by` is now **derived**
from `app.current_user_id()`, so the forgery is unrepresentable rather than merely refused, on the
RPC path and the direct path alike. Which permission should govern *opening* each approval type is a
separate question needing canon per type — recorded as **FIN-5**, not guessed.

---

## 6. Two mistakes of mine, both caught by tests

**The plpgsql RECORD hazard, walked into again.** My first guard used
`case tg_table_name when 'payments' then new.amount ... when 'invoices' then new.total_amount ...`.
plpgsql binds **every** referenced `NEW` field as a query parameter before the `CASE` chooses a
branch, so the invoices path still tried to resolve `new.amount` and failed. **That is exactly the
hazard SPEC-159-A already hit and documented in this repository**, and I repeated it. Rewritten with
`to_jsonb`, comparing by name — the shape `app.enforce_document_subscription_gate` already uses.
Caught by `38_class_a_events_test.sql`.

**A test that encoded the defect as an expectation.** Test 38 asserted *"a DIRECT allocation insert
succeeds — SEC-1 still permits it"*, running after `reset role` with a stale JWT claim, so
`auth.uid()` still resolved to an employee and FIN-3 correctly refused. The test's real purpose — that
the event comes from a **trigger** and therefore covers the direct path — is preserved by clearing
the claim so it is genuinely the system path `reset role` was modelling. **Third occurrence of this
fixture artifact**, after tests 31 and 37.

---

## 7. Regression proof

`56_financial_write_capability_test.sql` (12), every denial paired with the control that makes it
mean something:

- The employee **can see** the booking they own, and **holds no** `RECORD_PAYMENT` — so the denials
  are about capability, never about reach.
- Cannot record a payment, raise an invoice, or record a refund by direct DML.
- **Can** still add a quotation line — they hold `CREATE_QUOTATION`. A guard that broke the
  frontline's own job would be a worse defect than the one it fixed.
- Finance **does** raise the invoice and record the payment, and the row **persists** — so the
  denials are not blanket.
- FIN-4: the employee opens a request naming *finance* as requester; it is recorded against the
  **employee**.
- The session-less path still writes.

---

## 8. Environment, parity and guards — final state

| Axis | Value |
|---|---|
| Migrations | **148** — repository, local, Primary |
| Fingerprint | **`54bdef85d1d286ae77f92ed0681baaff`** on all three |
| Logic hash (`guard_financial_capability`, `derive_approval_requester`, their triggers) | **`45c3a2205d1c36448ea330f094b594ef`** identical local and Primary |
| pgTAP | **56 files / 633 assertions / 0 failures** |
| End-to-end HTTP | **118/118** — storage 36 · employee journey 29 · branches 26 · roles 27 |
| Smoke | `ALL CHECKS PASSED` |
| Guards | repository CLEAN · parity CLEAN (local proven; primary proven) |
| SEC-1 ceilings | 59 insertable · **36** without a capability trigger (**fell from 40**) |

---

## 9. Classification

**PROVEN** — money costs the same permission on RPC and direct DML across six tables, with positive
controls; approval-request attribution cannot be forged; the frontline's own capabilities are intact;
all four HTTP journeys still pass unchanged.

**UNPROVEN** — the trainee and `system_administrator` role journeys; the remaining lifecycle branches
(quotation rejected/expired/revised, booking modified, partial payment, supplier failure, document
expiry, repeat booking); the 17 remaining unguarded tables beyond the money family.

**FAILED** — none outstanding.

**BLOCKED** — **SEC-1** (architectural decision; inventory complete, exposure capped) · **FIN-5**
(which permission opens each approval type — canon per type) · **SYSADMIN-1** (`system_administrator`
holds zero permissions; intentionally empty, obsolete or undefined is a canon question) · TRANS-1 ·
TASK-3 · SCHED-1 · RET-1, RET-2, ORPH-1, LEAD-2, PLAN-1, BLOCKED-4/5, CANON-26-1 · DEL-1 (partial) ·
PP-1 · LIC-1 · EVT-2 · RBAC-2 · PERM-1.

**INTENTIONAL** — the capability guard exempts session-less paths; UPDATE is charged only when money
changes; RBAC-3; the department manager holding no branch-wide read.

---

## 10. Next logical work

**SEC-1 needs the owner's decision, and the inventory to make it is now complete** (§3). The money
family — the part that could be fixed without a decision, because canon already named the permission
and the RPC already charged it — is done.

**Independent of that decision:** the trainee and `system_administrator` journeys; the remaining
lifecycle branches over HTTP; the 17 non-money unguarded tables classified table by table against
canon; TRANS-1; SCHED-1.
