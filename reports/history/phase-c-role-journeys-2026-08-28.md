# ORVION — Phase C: The Role Journeys, and a Manager Who Could See Less Than Their Staff

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-28
Author: Claude Opus 5
Scope: Migrations `202607055700`–`202607055800`, tests `54` (updated), `55_role_coherence_test.sql`,
`10` (SEC-1 ceiling), script `scripts/verify_role_journeys.ps1`. The first role-by-role walk ORVION
has had. Closes **RBAC-4** and **TASK-2**; **reproduces SEC-1** and merges RLS-1 into it.
Status: Complete; deployed to Primary and pushed.

**Branch:** `main` · **Start HEAD:** `14f9d7f` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Objective

Phase C's directive §8: the employee has been walked twice; senior employee, branch manager,
department manager, finance, CEO, owner and platform owner have had none of that treatment. Give each
the same standard — a positive control proving the role can do its job, then negatives proving it
cannot do someone else's. And investigate the three carried findings (RLS-1, TASK-2, TRANS-1) rather
than implementing them blindly.

---

## 2. Starting state, re-proven live

| Axis | Evidence |
|---|---|
| GitHub | `origin/main` = `14f9d7f6d8db…` = local HEAD; tree clean |
| Repository | 145 migrations, 54 test files |
| Local + Primary | 145 migrations, fingerprint `89cd195343e88cd3f3faae44bbfe8f46` |
| Primary | 74 tables, 137 `app` functions, 73 endpoints, 119 policies, 3 cron jobs |

---

## 3. RLS-1 investigated → **SEC-1 reproduced**, and it is worse than recorded

The directive said prove current behaviour before changing anything. I built the role that RLS-1
warned about — holding **only** `VIEW_ALL_BRANCHES` and `VIEW_ASSIGNED_LEADS`, with
`CREATE_BOOKING = false` and `CREATE_TASK = false` — and had it write, by direct DML, over the
`authenticated` role:

| attempt | result |
|---|---|
| `update bookings set title = 'RENAMED BY AUDITOR'` | **succeeded** |
| `update tasks set title = 'RETITLED BY AUDITOR'` | **succeeded** |
| `insert into customers …` | **succeeded** (1 → 2 rows) |

`customers` is not one of RLS-1's eleven tables. So the class is wider than recorded, and the true
statement is architectural:

> **RLS scopes which rows a caller reaches. It does not enforce what they may do.** Capability lives
> in the `app.*` RPCs — which direct DML bypasses — and in a partial set of guard triggers covering
> archive, status transitions and financial columns. Creation and ordinary field edits are unguarded
> on the direct path across most of the schema.

Measured, not estimated: **59 tables accept a direct `INSERT` from `authenticated`; 19 have any
permission-checking trigger, and most of those cover only archive or status; 40 have no capability
check anywhere on the direct write path.**

**This is SEC-1**, an owner decision already open since 2026-08-21 ("whether `authenticated` should
hold direct table writes at all, since RLS scopes rows and not permissions"). RLS-1 is its concrete
instance and is **merged into it** rather than tracked twice. Its status moves from theoretical to
**reproduced**.

**Why I did not fix it.** Both coherent resolutions are architectural and neither is mine to choose:
revoke `authenticated`'s table writes and make the RPCs the only door (which requires converting them
to `SECURITY DEFINER` — a change to the entire authorization model), or enforce canon 28's matrix on
every table (which requires deciding, table by table, which permission governs creation — canon
territory). Inventing either would be inventing business policy.

**What I did instead.** Made the debt *measured* so it cannot silently grow: two ceiling assertions
in `10_grant_model_test.sql` (`<= 59` insertable, `<= 40` unguarded). The numbers may fall; they can
never rise without failing the suite.

---

## 4. RBAC-4 — a department manager could see nothing in their own department

Found by the role journeys, over HTTP:

```
DEPTMGR bookings=0  pipeline=0
        VIEW_DEPARTMENT_QUEUE=true  visible_depts=1  visible_branches=1
```

...with the booking sitting in exactly that department and branch. Everything the manager needed
resolved; the row was still invisible.

**Cause.** The `bookings` policy gates department reads on `VIEW_DEPARTMENT_RECORDS`. The seed granted
that to `employee` and `senior_employee` — **and not to `department_manager`**. Branch manager, CEO
and owner satisfy the other disjunct, so the omission lands on exactly one role: the one whose entire
job is that department.

**The inversion:** a department manager saw *fewer* bookings than the employees reporting to them.
The same permission gates booking items and quotations, so they could not see their department's
sales items or quotations either — the three objects the role exists to supervise.

**Why this is a defect and not policy I invented.** Canon 28: *"Department-level manager inside one
branch. Can manage employees and work inside their department and branch only."* Canon 28's own
amendment note introduces the permission for exactly this purpose — *"this permission is the
department-read gate for those three"* — and is explicit about where department managers **are**
deliberately excluded (note 3, `VIEW_BRANCH_DATA`: *"Department managers are still excluded"*). That
exclusion is about branch-wide reading and is untouched. Nothing in canon excludes a department
manager from their own department. The grant restores the scope canon already describes and widens
nothing: the manager gains exactly what every employee in that department already held.

**Guarded as a class** (`55_role_coherence_test.sql`): any department-scoped read gate an employee or
senior employee holds, the department manager must hold — *and* the department manager must still
hold no branch-wide read, so the fix cannot creep upward.

---

## 5. TASK-2 — a started task claimed it had been assigned

Canon 26 was decisive on both halves:

- `open → in_progress` = *"Responsible employee starts work"* — which **confirms TASK-1's fix** from
  the previous session was canon-aligned, not merely my reading of the role model.
- **Required Events**: `task_created`, `task_assigned`, `task_completed`, `task_cancelled`,
  `task_overdue`. **No start event.**

And `app.assign_task` already emits `task_assigned` — the correct producer. So the audit stream
contained `task_assigned` rows generated by two different business actions, only one of which was an
assignment. Anyone counting assignments per employee, or reconstructing who was given what work, was
reading inflated data.

**Fix: the transition emits nothing.** Adding a `task_started` code would be ORVION's engineering
inventing business vocabulary, which the directive forbids. A missing record is recoverable; a false
one silently corrupts every consumer that trusts it. `tasks.task_status_code` and `updated_at` still
record the change. Recorded as **TASK-3** if the business later wants start-of-work in the spine —
that is a canon amendment.

One structural consequence: `v_event is null` had meant "no such transition". Validity now comes from
`FOUND`, so the two legitimate eventless transitions are not mistaken for invalid ones. The parity
guard's regex was widened to keep comparing them — a pattern that only matched quoted events would
have silently stopped checking exactly those two rows, which is how TRANS-1 happened in the first
place.

---

## 6. TRANS-1 investigated, deliberately not "fixed"

The directive said change it only if evidence proves the duplication creates risk. It **has** caused
a fix to silently fail once. But `app.status_transitions` has no event column, so neither copy can be
deleted today without losing information, and rewriting nine `advance_*` functions at once is a
larger risk than the guarded duplication. Left guarded, with the de-duplication specified.

---

## 7. What the role journeys proved — 27 HTTP assertions, all passing

**Senior employee** — does the sales job; still cannot assign leads (same as employee); sees a
colleague's booking item **operationally** while its cost and profit are **NULL**.

**Branch manager** — sees their branch's pipeline and *not* the other branch's; holds `ASSIGN_LEAD`.

**Department manager** — sees their department's work (after RBAC-4) and not another branch's.

**Finance manager** — raises and issues invoices; sees **tenant-wide** profit, which is its job;
**cannot** grant roles and **cannot** create branches. Financial authority is not administrative
authority.

**CEO and owner** — both see tenant-wide profit across both branches and can grant roles. **Neither
can activate their own subscription or mint a licence token** — both get 404, because platform
authority is not a tenant permission. The owner *can* read their own subscription state.

**Platform owner** — reaches its own endpoint; a *tenant* reporting view is not its surface, because
it has no tenant context.

**Employee regression** — after Phase C changed guards, transitions and permissions: the personal
report still resolves with gross 3000 → commission 300 → company profit 2700, and the Alexandria
employee sees only their own.

### A correction worth recording

My first version asserted the senior employee sees **zero** rows in `booking_item_profit`. That would
have demanded the removal of legitimate operational visibility — canon grants department colleagues
sight of each other's work so a customer can be served when the assigned employee is away. The real
rule is **column-level**: the row is visible, the money is not. The assertion now checks the figures
are NULL. An earlier probe of mine also reported the senior seeing two items across branches; that
was a broken non-transactional `set local role` leaving the session as `postgres`. The system was
right both times; my measurement was wrong.

---

## 8. Environment, parity and guards — final state

| Axis | Value |
|---|---|
| Migrations | **147** — repository, local, Primary |
| Fingerprint | **`538c03737d2d1f03553d93c1d5a82785`** on all three |
| Logic hash (`advance_task`, `guard_booking_item_financials`, dept-manager grants, task transitions) | **`3a36360faf782ad0197ef0e17491b7b6`** identical local and Primary |
| pgTAP | **55 files / 621 assertions / 0 failures** |
| End-to-end HTTP | storage **36/36** · journey **29/29** · branches **26/26** · roles **27/27** |
| Smoke | `ALL CHECKS PASSED` |
| Guards | repository CLEAN · parity CLEAN (local proven; primary proven) |

---

## 9. Classification

**PROVEN** — every role's positive and negative controls listed in §7; column-level financial privacy
between colleagues; branch and department isolation; platform authority separated from tenant
authority in both directions; the employee journey intact after Phase C's changes.

**UNPROVEN** — the trainee and `system_administrator` roles (the latter holds **no permissions at
all**); the remaining customer-lifecycle branches (quotation rejected/expired/revised, booking
modified, partial payment, supplier failure, document expiry, repeat booking); Primary's endpoints as
an authenticated caller.

**FAILED** — none outstanding.

**BLOCKED** — **SEC-1** (owner decision, now reproduced; RLS-1 merged in) · TRANS-1, TASK-3 ·
SCHED-1 · RET-1, RET-2, ORPH-1, LEAD-2, PLAN-1, BLOCKED-4/5, CANON-26-1,
`suppliers.credit_limit_amount` · DEL-1 (partial) · PP-1 · LIC-1 · EVT-2 · RBAC-2 · PERM-1.

**INTENTIONAL** — RBAC-3 (employees cannot assign leads); the department manager holding no
branch-wide read; the 15 unexposed internal helpers; `pg_net` uninstalled; orphans never
auto-destroyed.

---

## 10. Next logical work

**SEC-1 is now the largest open item and it needs an owner decision**, not more engineering
discovery: should `authenticated` keep direct table writes (and every table gain a capability guard),
or lose them (and the RPCs become the only door)? The evidence is reproduced and the exposure is
measured and capped.

**Independent of that decision:** the remaining customer-lifecycle branches over HTTP; the trainee and
`system_administrator` roles; TRANS-1's de-duplication; SCHED-1.
