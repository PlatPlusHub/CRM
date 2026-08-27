# ORVION — Phase C, First Pass: The Journey Branches, and Two Capabilities That Were Dead

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-28
Author: Claude Opus 5
Scope: Migration `202607055600`, test `54_transition_permission_parity_test.sql`, script
`scripts/verify_journey_branches.ps1`. Walks the journey branches an agency actually works, over
HTTP, and fixes **FIN-2**, **TASK-1** and the drift (**TRANS-1**) that fixing TASK-1 exposed.
Status: Complete; deployed to Primary and pushed.

**Branch:** `main` · **Start HEAD:** `0e6621b` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Objective

API-1 proved the happy path: enquiry to cash. An agency does not spend its day on the happy path.
Phase C's first pass walks the branches — the cancelled booking, the refund, the complaint, the
supplier who must be paid, the discount needing a manager, the WhatsApp thread, the follow-up that
slipped — as real JWT-bearing users, to find what an agency would hit on day one.

---

## 2. Starting state, re-proven live

| Axis | Evidence |
|---|---|
| GitHub | `origin/main` = `0e6621b43f6e…` = local HEAD; tree clean |
| Repository | 144 migrations, 53 test files |
| Local + Primary | 144 migrations, fingerprint `95b67f1335820f641091f202c6610cd3` |
| Primary | 74 tables, 137 `app` functions, 73 endpoints, 119 policies, 3 cron jobs |

---

## 3. FIN-2 — the finance-approval workflow was dead for the role it exists for

**Symptom, live over HTTP as an employee holding `CREATE_BOOKING_ITEM`:**

```
POST /rest/v1/rpc/request_finance_approval  ->  403  permission denied: APPROVE_FINANCE
```

**Two halves, each correct on its own:**

- `app.request_finance_approval` charges `CREATE_BOOKING_ITEM`. Correct — the requester is the
  salesperson who wants a discount signed off.
- `app.guard_booking_item_financials`, the trigger on `booking_items`, charged `APPROVE_FINANCE`
  whenever `finance_approval_status_code` changed at all.

...and the RPC sets that column to `'pending'`. So the RPC charged the salesperson's permission and
the trigger immediately charged the approver's. **Only a holder of `APPROVE_FINANCE` could open a
request — that is, only the approver could ask themselves for approval.** `APPROVE_FINANCE` belongs
to ceo, finance_manager and owner; the employees and senior employees who actually raise discounts
hold none of it.

**Root cause:** the guard treated one column as one privileged act, when it carries two:

| transition | act | actor |
|---|---|---|
| `null / rejected / cancelled → pending` | **requesting** | the salesperson |
| `pending → approved / rejected / cancelled` | **deciding** | finance |

A control that cannot tell a request from a decision must refuse both, and it did.

**Fix:** the guard now distinguishes them. Requesting costs exactly what the RPC always said —
`CREATE_BOOKING_ITEM` plus the same assignment scope every other financial edit on this table
requires, so an employee still cannot open a request against a colleague's item. Deciding still
costs `APPROVE_FINANCE`. `cost_locked_at` is untouched and remains approver-only.

Proven over HTTP: employee **requests** ✓ · employee **cannot approve their own** ✓ · finance
**can** ✓ (the positive control, without which the denial would prove nothing).

---

## 4. TASK-1 — an employee could create and complete a task, but not start one

`app.advance_task` mapped `open → in_progress` and `overdue → in_progress` to `ASSIGN_TASK`, held
only by branch_manager, department_manager, ceo and owner. `COMPLETE_TASK` — held additionally by
employee and senior_employee — governed every other transition.

So the frontline could open a follow-up and close it, and could not mark it as being worked on.
`in_progress` was unreachable for the people whose work it describes, quietly turning the task board
into a two-state system.

**Root cause:** starting a task was conflated with assigning one. They are different acts with
different actors — `app.assign_task` already exists and is where `ASSIGN_TASK` belongs.

---

## 5. TRANS-1 — fixing TASK-1 did not fix TASK-1, and that is the important finding

After changing `app.advance_task`, the employee was **still** refused with
`permission denied: ASSIGN_TASK`. The transition rules live in **two** places:

1. an inline `VALUES` list inside each `app.advance_*` function — carries *(from, to, **event**,
   permission)*
2. **`app.status_transitions`** — carries *(table, status column, from, to, permission)*, read by
   `app.enforce_status_transition`, the BEFORE UPDATE trigger on every status-bearing table

**The trigger is the real boundary** — it fires on the RPC path *and* on direct DML — so the table is
authoritative and the function's copy is a duplicate. I edited the copy. The bug survived the fix,
and I had introduced a live drift between the two sources.

Found by diffing all nine `advance_*` functions against `app.status_transitions`. Both rows are now
corrected, and the diff is a permanent test — `54_transition_permission_parity_test.sql` — with a
positive control so the parity checks cannot pass on an empty parse.

The duplication itself is **not** removed here: `app.status_transitions` has no event column, so the
function's list is currently the only home for the event code. Giving that table an event column and
making it the single source is recorded as **TRANS-1** rather than done in passing.

---

## 6. What the branches proved — 26 HTTP assertions, all passing

`scripts/verify_journey_branches.ps1`, as real users:

**Tasks** — create, start, complete. **Conversations** — a WhatsApp thread opened against a booking
and a message sent. **Document versioning** — upload, corrected version, and version 2 becoming
current. **After-sales** — complaint logged and acknowledged; service request raised. **Supplier** —
finance records the supplier payment, and *an employee cannot* (supplier money is finance's).
**Approvals** — the FIN-2 triangle above. **Refund and cancellation** — a partial refund recorded and
advanced by finance; the booking item cancelled; **and the cancelled item correctly leaves the
employee's performance report**, so a cancelled sale pays no commission.

**Financial privacy across the branch**, which is the rule that had to survive all of the above: the
employee sees their **own** item's profit; a second employee in the **same branch and department**
sees none of it, and their personal report is empty rather than showing their colleague's.

---

## 7. A domain rule that was right, and a role rule that was right

**`upload_document` refused a passport linked to a booking:** *"passport documents are stored at
passenger level"*. That is a correct rule — a passport belongs to a person, not an itinerary — so the
fixture was corrected, not the rule.

**Carried forward from API-1:** an employee cannot assign leads. Investigated rather than granted —
the `leads` policy grants visibility on `owner_user_id` and `create_lead` stamps the creator as
owner, so an employee works their own lead without assigning it. Recorded INTENTIONAL (RBAC-3).

---

## 8. Findings recorded, not fixed

**RLS-1 — read scope is write scope on 11 tables.** `booking_items`, `bookings`, `complaints`,
`conversations`, `customer_notes`, `document_links`, `documents`, `leads`, `quotations`,
`service_requests` and `tasks` carry `for ALL` policies whose `USING` **and** `WITH CHECK` both
include `app.has_tenant_wide_read()` — which is `has_permission('VIEW_ALL_BRANCHES')`. So a **read**
permission confers **write** authority.

Not exploitable today, and that is stated rather than used as an excuse: only `owner` and `ceo` hold
`VIEW_ALL_BRANCHES`, and both already hold every write permission, so no one gains anything they did
not have. It is **latent**: the day a read-only auditor role is given `VIEW_ALL_BRANCHES` for
reporting, it silently gains INSERT and UPDATE on eleven tables. The structural repair — a separate
`has_tenant_wide_write()` predicate in `WITH CHECK` — is behaviour-preserving today but touches the
most heavily tested policies in the system, so it is scoped as its own package rather than done at
the end of a session.

**TASK-2** — both `→ in_progress` transitions still emit `task_assigned`, so the audit trail will say
"assigned" when nothing was assigned. The honest repair is a `task_started` event type; the event
vocabulary is closed and canon-owned, so adding a code is a vocabulary decision, not a permission bug.

---

## 9. Tests: added, failed first, corrected

Suite **53 files / 612 assertions → 54 files / 615 assertions**, 0 failures. Plus 36 storage + 29
journey + 26 branch HTTP assertions.

| What failed first | Cause | Resolution |
|---|---|---|
| 5 branch steps: invalid catalog codes | my fixture invented vocabulary again (`accommodation`, `modification`, `customer_request`, `employee` sender, `medium` severity) | read the real catalogs |
| "...and completes it" reported failing | **PostgREST answers a void RPC with 204**; I only accepted 200 | the script was wrong, not the code |
| passport → booking refused | correct domain rule | fixture corrected |
| "employee sees their OWN profit: rows=0" | I measured **after** the cancellation, so I was measuring the cancellation | moved the check before the branches |
| `ASSIGN_TASK` still denied after the fix | **TRANS-1** — the second source | both sources fixed; parity now guarded |
| my `advance_task` rewrite dropped `and tenant_id = v_tenant` | I rewrote from a fragment instead of the live definition | caught by diffing before it ran; restored to a minimal diff |

---

## 10. Environment, parity and guards — final state

| Axis | Value |
|---|---|
| Migrations | **145** — repository, local, Primary |
| Fingerprint | **`89cd195343e88cd3f3faae44bbfe8f46`** on all three |
| Logic hash (`guard_booking_item_financials`, `advance_task`, task transitions) | **`c49542186e0b77adb9991505ed0bbb34`** identical local and Primary after comment/whitespace normalisation. Primary's stored function comments are abbreviated relative to the repo; the executable logic is proven equal, and the migration file remains the source of truth |
| pgTAP | **54 files / 615 assertions / 0 failures** |
| End-to-end HTTP | storage **36/36** · journey **29/29** · branches **26/26** |
| Smoke | `ALL CHECKS PASSED` |
| Guards | repository CLEAN · parity CLEAN (local proven; primary proven) |

---

## 11. Classification

**PROVEN** — tasks, conversations, document versioning, complaints, service requests, supplier
payment (and its denial to employees), the finance-approval triangle, refunds, cancellation, a
cancelled item paying no commission, and financial privacy between colleagues in the same
branch — all over HTTP as real users; transition-permission parity across both sources.

**UNPROVEN** — the manager, department-manager, CEO and platform-owner journeys; the reporting views'
contents as each role; Primary's endpoints as an authenticated caller (needs a project-signed JWT).

**FAILED** — none outstanding.

**BLOCKED** — RLS-1 (scoped as its own package) · TASK-2, TRANS-1 (engineering, scheduled) · SCHED-1 ·
RET-1, RET-2, ORPH-1, LEAD-2, PLAN-1, BLOCKED-4/5, CANON-26-1, `suppliers.credit_limit_amount`
(business) · DEL-1 (partial) · PP-1 · LIC-1 · EVT-2 · RBAC-2 · PERM-1.

**INTENTIONAL** — RBAC-3 (employees cannot assign leads); passports linked at passenger level; the 15
unexposed internal helpers; `pg_net` uninstalled; orphans never auto-destroyed.

---

## 12. Next logical work

**Phase C continued — the table-by-table audit** across all 74 tables (schema, FKs, RLS, grants,
triggers, events, reporting, integrations) for behavioural consistency rather than existence.

**Then:** the manager / finance / CEO / platform-owner role journeys over HTTP — the same treatment
the employee journey has now had twice, for the roles that have had none. **RLS-1** as its own
package. **SCHED-1**.
