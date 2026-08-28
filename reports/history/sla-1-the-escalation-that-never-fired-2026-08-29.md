# ORVION — The Escalation Canon Calls Mandatory, and Which Had Never Fired

Class: History (point-in-time record; superseded by later reports, never edited retroactively)
Date: 2026-08-29
Author: Claude Opus 5
Scope: Migration `202607056600`, test `63_sla_escalation_test.sql`.
Status: Complete; deployed to Primary and pushed.

**Branch:** `main` · **Start HEAD:** `be65ef5` · **Environment:** Primary `vrvtsxexkiiiivlkdxzp` only.

---

## 1. Starting state, re-proven before anything was touched

| Axis | Evidence |
|---|---|
| GitHub | `gh api` = local HEAD = `be65ef5a4928…`; tree clean |
| Repo / local / Primary | **154** migrations, fingerprint `73f01c3ae5e56754affbee87ba20f8ff` on all three |
| Primary shape | 74 tables · 75 `public` functions (74 endpoints + Supabase's `moddatetime`) · 119 policies · 3 cron jobs |
| pgTAP, Pass B (residue already present) | **62 files / 717 assertions / 0 failures** |

The reported baseline held exactly. Nothing had drifted.

---

## 2. How the package was selected

Working the directive's §8 lead-operations checklist against the live system. Ten of its twelve items
(A–L) were already satisfied by existing machinery — `lead_assignments` history, the immutability
guard `app.forbid_assignment_history_rewrite`, `lead_reassigned` events, the round-robin
auto-reassignment, the subscription-gate skip that stops one restricted tenant aborting the shared
run, `pg_cron` running the processor every minute.

Item **F — "the responsible manager can see the overdue condition"** did not survive inspection.

---

## 3. The canonical requirement, quoted rather than inferred

canon 04 § *SLA Escalation Rule*:

> If a lead is not responded to within 15 minutes:
> — Notify the assigned employee.
> — **Notify the employee's manager.**
> — Record an escalation event.

canon 10 § *Lead Notifications*:

> After 15 minutes without response: Notify assigned employee. **Notify manager.**
> After another 15 minutes without response: Notify reassigned employee. **Notify manager.** Record
> reassignment event.

canon 10 also lists **"Manager escalation" among the notifications users cannot mute.** This is
mandatory operational behaviour, and the 15/30-minute windows already matched
`app.process_lead_sla`'s defaults — so neither the requirement nor the timing is invented here.

---

## 4. Reproduced, with the control that makes it mean something

Standard configuration: an employee, a `branch_manager` and a `department_manager`, all placed in the
branch/department through `user_branch_assignments`, all holding **tenant-scoped** roles — which is
precisely what `app.assign_user_role` produces, since `p_scope_type` defaults to `'tenant'` and
leaves `branch_id`/`department_id` NULL.

One SLA pass:

```
 1-Emp         1 notification (lead_sla_warning)
 2-BranchMgr   0
 3-DeptMgr     0
```

and in the same transaction, before the pass: `manager_can_see_the_lead = 1`.

**A notification failure, not an unreachable row.** Without that control the zero would have proved
nothing.

### Root cause — the recurring shape, this time in the operational layer

The manager lookup asked:

```sql
and (ura.branch_id = r.branch_id or ura.department_id = r.department_id)
```

of `user_role_assignments` **alone**. ORVION's authoritative definition of which branches and
departments a user governs is `app.visible_branch_ids()` / `app.visible_department_ids()`, and each
is a **union** of three sources: tenant-wide read, the user's `user_branch_assignments` **placement**,
and scoped `user_role_assignments`. The SLA lookup used only the third — the one that is NULL for
every role assignment ORVION's own RPC creates by default. So the predicate evaluated `NULL = uuid`
and was never true.

Two definitions of one concept, and the narrower one sat in the place that mattered. The same shape
as the transition-parity test that checked one function out of ten and the capability detector that
recognised one function name — except this one was not a guard reporting false health, it was the
product behaving wrongly.

### A second instance in the same function

The reassignment branch notified only the **new assignee**. Canon 10 requires the manager to be told
there too, and that branch had **no manager notification at all** — not mis-scoped, simply never
written.

---

## 5. Why no existing guard caught it

`34_event_write_path_test` and `36_subscription_gate_system_paths_test` both exercise
`process_lead_sla` — but they assert the **system-path survival** and the **subscription-gate
isolation**: that the *event* is emitted, for the right tenant, without one lapsed tenant aborting
the run. **Neither asserts who is notified.**

So this was not a guard that lied. It was a canonical requirement with no coverage at all — worth
distinguishing, because the remedy is different: widen a detector versus write the missing test.

---

## 6. The fix, and what was deliberately left alone

`app.lead_responsible_managers(tenant, branch, department, exclude_user)` holds the scope rule **once**
and is used by **both** paths — because a second copy of a predicate is what produced this defect. It
mirrors `visible_branch_ids`/`visible_department_ids` for an *arbitrary* user (those read the session;
this runs with none), and adds the `is_active` / `starts_at` / `ends_at` bounds the authoritative
functions apply and the old inline predicate omitted — SPEC-148's rule that revocation is complete.

The tenant-wide-read source is deliberately absent: it resolves to ceo/owner, who are not in canon's
escalation path.

**Not changed, and each for a stated reason:** which roles escalate (still `branch_manager` /
`department_manager` — widening to ceo/owner would be new policy, not a defect fix); the 15/30-minute
windows; the warn-before-reassign ordering; the qualifying-interaction definition; the round-robin
choice of the next assignee; the subscription-gate skip; the event vocabulary; the immutability of
assignment history.

After the fix, the identical probe: employee **1**, branch manager **1**, department manager **1**.

---

## 7. A correction to my own test, before it ever shipped

The first version of `63_sla_escalation_test.sql` **passed assertion 10 for the wrong reason.**

The reassignment pool is *everyone placed in the branch/department*, which includes the managers.
With no prior assignments every `last_at` is NULL and the tie breaks on `u.id asc` — so the lead was
reassigned to the **branch manager**, and their own *"reassigned to you"* notification was being
counted by an assertion that claimed to be counting manager escalations. Eleven green assertions, one
of them measuring something other than its description.

The fixture now gives the colleague the lowest id so the round robin picks them deterministically,
and a new assertion pins the resulting assignee explicitly so the two populations cannot overlap.
Recorded here because it is exactly the shape this programme exists to catch, and I produced it.

---

## 8. Found while proving it, and deliberately not fixed: LEAD-3

That the pool includes managers is itself a question. canon 04 says *"Reassign the lead to another
**eligible employee**"* and defines neither "eligible" nor whether a manager qualifies. Both readings
are defensible — loosely, any staff member placed in that team; strictly, a front-line handler, with
the manager as escalation target rather than next handler.

It is pre-existing behaviour, it is not a security issue (a `branch_manager` holds `ASSIGN_LEAD` and
can legitimately work the lead), and this migration is about **who is notified**, not **who receives
the work**. Conflating them would have shipped an unrequested policy change inside a defect fix.
Recorded as **LEAD-3, BLOCKED — BUSINESS DECISION.**

---

## 9. Verification

| Axis | Value |
|---|---|
| Migrations | **155** — repository, local, Primary |
| Fingerprint | **`61a213f3040452ed3ca2cf552f22a882`** on all three |
| Logic hash (`process_lead_sla` + `lead_responsible_managers`) | **`4c698170f5c6e96112dcdf7d8a134bfb`** identical local and Primary |
| pgTAP **Pass A** (fresh `db reset`) | **63 files / 728 assertions / 0 failures** |
| pgTAP **Pass B** (after all five HTTP suites' residue) | **63 files / 728 assertions / 0 failures** |
| End-to-end HTTP | **179/179** — storage 40 · employee 29 · branches 26 · roles 27 · lifecycle 57 |
| Smoke | `ALL CHECKS PASSED` |
| Guards | repository CLEAN · parity CLEAN |

---

## 10. Classification

**PROVEN DEFECT (fixed)** — SLA-1: the canon-mandated manager escalation never fired, on both the
warning and the reassignment paths.

**BLOCKED — BUSINESS DECISION (new)** — LEAD-3: the composition of the reassignment pool.

**INTENTIONAL** — the escalation role set; the exclusion of tenant-wide-read holders; the outgoing
assignee receiving no separate notice (canon requires none, and one was not invented).

**UNPROVEN** — nothing outstanding from this package.

---

## 11. Next logical work

Continue the directive's §8 checklist at item **J** — that lead reassignment does not rewrite
acquisition attribution (`leads.attribution_click_id`). The SLA reassignment path updates
`assigned_user_id` and `owner_user_id` and touches nothing else, which *reads* correct, but "reads
correct" is what this report exists to distrust: it has not been asserted, on either the automatic
path or `app.reassign_lead`'s human one.
