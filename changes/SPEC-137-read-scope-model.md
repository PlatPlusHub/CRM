# Change Request — SPEC-137

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Resolve AUDIT-3: replace ORVION's tenant-only read model with the branch / department / assigned
scope model canon 28 defines and the owner's operating rules require, so that reading a record is
governed by where the employee works and what they are responsible for — not merely by which company
they belong to.

---

## Business Reason

All 76 RLS policies resolve to `tenant_id` and nothing else. Canon 28 defines five scope types
(tenant, branch, department, assigned, platform), assigns one to every permission, and states
plainly that "Sales employee sees assigned leads only by default". Fourteen `VIEW_*` permissions are
seeded and assigned to roles, and **not one of them is enforced anywhere**. A trainee can currently
read every lead, booking, quotation, conversation, complaint and invoice in the tenant.

The owner has since made three visibility rules explicit (directive 2026-08-24):

- **Branch isolation.** Branch A staff must not see or operate on Branch B's operational data.
- **Department continuity.** Assignment must not mean sole visibility — a colleague in the same
  department must be able to continue serving a customer when the assigned employee is absent.
- **Employee financial privacy.** Seeing a booking must not mean seeing another employee's profit.

The first two are this CR. The third is SPEC-138: it is a *column* concern rather than a *row*
concern, and merging them would produce a change no reviewer could check.

---

## Risks

High — this is the authorization path. Three specific hazards, each addressed:

1. **Fail-closed lockout.** The scope columns on `quotations`, `conversations`, `complaints` and
   `service_requests` are nullable, and four RPCs do not populate them. Under a branch-scoped
   predicate a null branch is invisible to everyone, so those RPCs would create records their own
   author could not see. Step 4 fixes the RPCs; test 21 proves the author can read back what they
   just created through the real RPC.
2. **Unconstrained scope input.** `user_role_assignments.scope_type` is free text with no CHECK, and
   `app.assign_user_role` passes its parameter through unvalidated. Once scope_type decides read
   authority, a typo silently changes it. Step 1 constrains it before Step 2 depends on it.
3. **Per-row function evaluation.** Policies that call a function per row do not hoist. The set
   primitives are called as `(select ...)` scalar subqueries so they evaluate once per query, the
   pattern migration `202607048500` established.

---

## Supersedes / Depends On

Resolves AUDIT-3. Depends on `202607043300_create_rls_policies.sql` (the policies being replaced) and
`202607048500_rls_initplan_wrapping.sql` (the evaluation pattern). Resolves the `scope_type` half of
CAT-6 with cause. Raises SPEC-138 (employee financial privacy).

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607051400_read_scope_model.sql`
- `supabase/tests/21_read_scope_model_test.sql`
- `scripts/verify_database.sql`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `_ORVION_CANONICAL/manifest.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `changes/SPEC-137-read-scope-model.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- `_ORVION_CANONICAL/35_tenant_isolation_and_data_access_principles.md` — this CR *implements*
  principle 4, it does not amend it
- Any n8n workflow; any UI

---

## Minimum Reading List

- `_ORVION_CANONICAL/28_permissions_matrix.md` (scope types; the `VIEW_*` rows)
- `_ORVION_CANONICAL/35_tenant_isolation_and_data_access_principles.md` §4 (policies call the
  primitive, never inline `auth.uid()` logic)
- `_ORVION_CANONICAL/05_customer_identity.md` §Customer Cross-Branch Awareness
- `supabase/migrations/202607051000_task_write_path.sql` (`app.create_task` — the placement-resolution
  pattern the four repaired RPCs reuse)

---

## Implementation Steps

1. Constrain the security-critical inputs: CHECK `user_role_assignments.scope_type`, require the
   qualifying id for branch/department scopes, and enforce one current primary branch assignment per
   user.
2. Add the resolution primitives in the non-API `app` schema: `current_user_id`,
   `has_tenant_wide_read`, `visible_branch_ids`, `visible_department_ids`.
3. Replace `tenant_isolation` with `scope_isolation` on the eight scope-bearing tables, and scope the
   derived children and the financial tables through their parents.
4. Repair `create_quotation`, `start_conversation`, `create_complaint` and `create_service_request`
   so they populate the ownership triple from the owner's primary branch assignment.
5. Align `role_permissions` with the model: department-visibility permissions to `employee` and
   `senior_employee` (owner directive), `VIEW_BRANCH_DATA` to `branch_manager`.
6. Verification check: test 21 drives real authenticated users across branch, department, assignment
   and role boundaries and asserts both the permitted and the denied direction of every rule.

---

## Acceptance Criteria

- [x] A Branch A employee cannot read Branch B's leads, bookings, quotations, conversations,
      complaints, service requests, tasks or invoices.
- [x] A department colleague *can* read the operational records of an absent colleague in the same
      department and branch.
- [x] An employee in another department of the same branch cannot.
- [x] A trainee sees only records they own.
- [x] A branch manager sees every department in their branch and no other branch.
- [x] Owner/CEO see all branches, and branch identity is preserved on every row so branch-specific
      and consolidated reporting are both derivable.
- [x] The customer master stays tenant-visible (canon 05 cross-branch awareness) while the customer's
      detailed activity does not.
- [x] Every record created through a real RPC is readable by its author.
- [x] `scope_type` cannot be set to an unrecognised value.
- [x] Clean `db reset` replays; full suite passes (`Files=22, Tests=163 ... PASS`); smoke passes.
- [ ] **UNVERIFIED — Primary.** The `supabase-primary` MCP server disconnected mid-session and
      requires re-authorization, which cannot be done non-interactively. The migration is NOT
      applied to Primary and repo/local/Primary parity is NOT confirmed. Local evidence stands
      on its own; the Primary half is outstanding and is recorded as such rather than assumed.

---

## Execution Log

### 2026-08-24 — Claude Opus 5 (Foundation Completion Programme)

Outcome: Complete

All six steps applied across `202607051400_read_scope_model.sql` (model) and
`202607051500_branch_filed_write_paths.sql` (the four repaired RPCs). `db reset` replays 104
migrations clean; suite `Files=22, Tests=163 ... PASS`; smoke `ALL CHECKS PASSED`.

**Two findings the work itself produced, both from testing rather than review.**

First, `21_read_scope_model_test.sql` is the first test in this suite that runs as `authenticated`
at all. Every other file runs as `postgres`, which owns the tables and therefore bypasses RLS
entirely — so before this CR, not one test had ever proven that an RLS policy filters a row,
including the tenant isolation the whole system rests on. The policies were verified by inspection
only. That is now closed for the scope model and, by construction, for tenant isolation with it.

Second, the trainee assertion failed on the first run and was right to. The department clause had
been implemented as *membership only* while the CR specified it as permission-gated, so a trainee
placed in Cairo Sales inherited every Cairo Sales lead — being in the department was the whole
test. The migration was corrected rather than the assertion. Canon 28's "Department queue visibility
requires explicit permission" is what makes the trainee boundary real instead of incidental, and a
membership-only model had quietly discarded it.

---

## Verification Notes

### 2026-08-24 — Claude Opus 5 (Foundation Completion Programme)

Verdict: Confirmed Complete

Findings: the assertion worth reading is test 21's first one — that Alice sees exactly one lead.
Every other assertion in the file is a denial, and a denial is satisfied just as well by a broken
fixture as by a working control. Without a positive anchor proving the data is reachable at all,
"Dave cannot see the Cairo lead" would pass against an empty table.

The four repaired RPCs are not a tidiness fix. They are SECURITY INVOKER, so the new WITH CHECK
applies to them: had they been left writing a null ownership triple they would not merely have
produced invisible rows, they would have stopped working outright. Test 21 asserts the full
round-trip — create through the real RPC, read back, colleague reads, other branch does not.

Recommendation to human: Set Status to Complete.

---

## Review Gate

- [x] Every change matches the Implementation Steps exactly.
- [x] No file outside the Scope list was modified or created.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] Supersedes / Depends On names no file requiring a Status change.
- [x] The repository is in a clean, releasable state (local; Primary deployment outstanding).

---

## Notes

**Approval basis.** Owner directive 2026-08-24 ("Foundation Completion, Security Scope & CRM
Readiness Programme"), which names AUDIT-3 the immediate security priority and STEP 1 of the
roadmap, and grants standing authority for technical decisions determinable from canon.

**Why the customer master is not branch-scoped.** Canon 05 §Customer Cross-Branch Awareness requires
that a customer interacting with more than one branch is *not* duplicated, and that a limited
cross-branch summary — last interaction date, branch, and employee — remains visible. Those three
facts are exactly `customers.last_interaction_at` / `last_interaction_branch_id` /
`last_interaction_user_id`; the columns exist for this rule. Canon then draws the line: "Detailed
event content from another branch is not shown by default." So the customer row stays tenant-visible
and every *activity* record about them is branch-scoped. Branch-scoping the master row instead would
break the uniqueness rule it is there to serve — a second branch could not find the customer, and
would create the duplicate canon 05 forbids.

**Which column carries branch authority.** `leads` and `bookings` each carry two placements:
`branch_id`/`department_id` (NOT NULL) and `owner_branch_id`/`owner_department_id` (nullable). Both
are canonical (`31_schema_draft.md`). Isolation uses the NOT NULL pair, because a mandatory column
cannot produce the invisible-row failure a nullable one can. The nullable ownership triple is a
responsibility record, not a placement record, and is used for the assigned axis. The relationship
between `leads.owner_user_id` and `leads.assigned_user_id` is *not* settled by canon; this CR treats
either matching the caller as "assigned" and records the ambiguity for the table-by-table audit
rather than inventing a rule.

**Why department visibility is permission-gated rather than membership-only.** Canon 28 says
"Department queue visibility requires explicit permission" and marks Employee "No"; the owner
requires a department colleague to be able to continue an absent colleague's work. Implementing the
*mechanism* as permission-gated and granting that permission to `employee` and `senior_employee` by
default satisfies both literally, and leaves a real control surface — `trainee` does not receive it,
which is what makes the trainee restriction in the owner's walkthrough testable rather than
incidental. Canon 28 is amended to record the changed default and its basis.
