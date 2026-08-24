# Change Request — SPEC-148

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Cover what happens when access is taken away — an employee leaves, a role assignment expires, a role
is deactivated — and record the semantic that testing it revealed.

---

## Business Reason

The owner's directive asks three questions no test answered: what happens when an employee leaves,
when an employee loses a permission they previously had, and when a role changes. Every other test in
the suite grants access and checks it works. Access controls fail in the other direction too, and
that failure is silent — a departed employee whose session still resolves is not something anyone
notices until it matters.

This is test-only: no migration, no behaviour change. It is regression coverage for behaviour
delivered by SPEC-137 and SPEC-146, plus the record of a semantic those CRs implied without stating.

---

## Risks

None to the system. The risk this closes is that a future change to `app.current_tenant_id()` or
`app.has_permission()` could quietly stop honouring `users.is_active`, `user_role_assignments.ends_at`
or `roles.is_active`, and nothing would fail.

---

## Supersedes / Depends On

Depends on SPEC-137 (the resolution primitives) and SPEC-146 (the permission-gated `assigned` scope).

---

## Scope — Files Allowed to Modify

- `supabase/tests/31_access_revocation_test.sql`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `changes/SPEC-148-access-revocation-coverage.md`

---

## Out of Scope — Files Forbidden to Modify

- Every migration. This CR adds no schema, policy or function change; if an assertion had failed for
  a reason other than a wrong expectation, that would have been a separate CR.

---

## Minimum Reading List

- `supabase/migrations/202607051400_read_scope_model.sql` (the primitives)
- `_ORVION_CANONICAL/28_permissions_matrix.md` §Read Scope Enforcement

---

## Implementation Steps

1. Assert the baseline first, so every subsequent "cannot see" is a control rather than a broken
   fixture.
2. Deactivate the user; assert the resolution chain is cut at the root.
3. Expire the role assignment; assert `ends_at` is enforced.
4. Deactivate the role itself; assert the same result by a different route.

---

## Acceptance Criteria

- [x] A departed employee resolves to no tenant and no user.
- [x] They see nothing on any table, and hold no permission.
- [x] An expired role assignment stops granting.
- [x] A deactivated role stops granting.
- [x] Full suite passes (`Files=31, Tests=276`).

---

## Execution Log

### 2026-08-24 — Claude Opus 5 (Final Foundation Hardening)

Outcome: Complete

Suite `Files=31, Tests=276 ... PASS`.

Assertion 9 was written expecting the opposite of what happened, and the implementation was right.
It originally read "their OWN lead is still visible, because ownership is a fact about the record and
not a permission" — reasonable-sounding, and wrong. Canon 28 makes seeing your assigned work a
*permission* (`VIEW_ASSIGNED_LEADS`), which SPEC-146 began enforcing. An employee whose role
assignment has lapsed holds no permissions at all, so they hold that one no longer either.

The assertion was corrected rather than the code, and the semantic is now recorded in canon 28:
**role expiry is a complete revocation, not a partial one.**

---

## Verification Notes

### 2026-08-24 — Claude Opus 5 (Final Foundation Hardening)

Verdict: Confirmed Complete

Findings: assertion 3 is the one that matters most, and it is cheap only because the architecture is
right. Deactivating the user cuts `app.current_tenant_id()`, and because canon 35 principle 4 forced
every policy to resolve through that one primitive, the effect reaches all 72 tables at once without
anything else being touched. A model where each policy had inlined its own `auth.uid()` logic would
need this proven per table, and would eventually miss one.

Assertion 10 exists because expiry and deactivation are different routes to the same revocation, and a
control that honoured one but not the other would let a tenant disable a role and leave its holders
fully empowered.

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

**Approval basis.** Owner directive 2026-08-24 (second directive) §2, which names "What happens when
an employee leaves?", "What happens when an employee loses permission after previously having it?" and
"What happens when a role or plan changes?" among the questions that should drive the audit.
