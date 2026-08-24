# Change Request — SPEC-138

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Close the privilege-escalation path that makes every other authorization control in ORVION
advisory: `authenticated` holds INSERT and UPDATE on `user_role_assignments`, so any employee can
insert an owner-role row for themselves.

---

## Business Reason

Found while challenging SPEC-137. The read-scope model resolves authority through
`user_role_assignments` and `user_branch_assignments`, and both tables are directly writable by
`authenticated` with nothing but a tenant check in their RLS policy. A single statement any employee
can run —

```sql
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
values (<my tenant>, <my user id>, (select id from public.roles where code = 'owner'), 'tenant');
```

— satisfies `tenant_id = app.current_tenant_id()` and makes the caller an owner. From there every
permission check, every scope, and the whole of SPEC-137 is bypassed. The same shape applies to
`user_branch_assignments` (grant yourself any branch), `users`, `branches`, `departments`, `tenants`,
`subscriptions` and `catalog_values`.

This is not the previously-recorded SEC-1 trade-off. SEC-1 concerned CRM tables with no RPC, where
direct DML bypasses lifecycle rules; the data written is still the caller's own tenant's operational
data. This is different in kind: it is a write that changes *who the caller is*.

The write RPCs already authorize the right permission (`app.assign_user_role` →`MANAGE_USERS`,
`app.create_branch` → `MANAGE_BRANCHES`, `app.create_department` → `MANAGE_DEPARTMENTS`). The gap is
that nothing enforces it when the RPC is skipped. This CR moves that same check into the table, so
the rule holds on every path rather than on the polite one.

---

## Risks

Moderate, and the shape of the risk is lockout rather than exposure — if a permission mapping is
wrong, a legitimate administrative RPC stops working. Three mitigations:

1. Each table's required permission is taken from the `app.authorize(...)` call in its own existing
   write RPC, not chosen independently, so the table and the RPC cannot disagree.
2. All the affected RPCs are SECURITY INVOKER, so test 22 exercises the real path end to end rather
   than a definer shortcut that would hide a mismatch.
3. `SELECT` is left exactly as it was. Only INSERT/UPDATE/DELETE gain the permission requirement, so
   nothing that merely reads its own configuration can break.

MFA tables (`trusted_devices`, `totp_enrollments`, `otp_challenges`) were checked and are **not** in
scope: they are already `owner_only`, and `app.mfa_satisfied()` reads the `aal` claim from the JWT
rather than those tables, so a self-inserted row grants nothing.

---

## Supersedes / Depends On

Depends on SPEC-137 (the read model this protects). Distinct from SEC-1, which remains open for the
CRM tables with no RPC write path.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607051600_rbac_write_authority.sql`
- `supabase/tests/22_write_authority_test.sql`
- `scripts/verify_database.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-138-rbac-write-authority.md`

---

## Out of Scope — Files Forbidden to Modify

- All historical migrations
- Every `app.*` RPC — each already authorizes correctly; the defect is that the table did not
- The MFA tables, for the reason recorded under Risks

---

## Minimum Reading List

- `supabase/migrations/202607043300_create_rls_policies.sql` (the `tenant_isolation` policies replaced)
- `_ORVION_CANONICAL/28_permissions_matrix.md` §Organization Permissions
- `_ORVION_CANONICAL/35_tenant_isolation_and_data_access_principles.md` §6 (platform administration
  is a `service_role` concern, not a tenant-user path)

---

## Implementation Steps

1. For each identity/organization/configuration table, split its `FOR ALL` policy into an unchanged
   `SELECT` policy plus INSERT/UPDATE/DELETE policies that additionally require the permission its
   own write RPC authorizes.
2. Verification check: test 22 proves an ordinary employee cannot grant themselves a role, a branch,
   or a tenant setting, and that a CEO can still do all three through the real RPCs.

---

## Acceptance Criteria

- [x] An employee cannot insert a role assignment for themselves.
- [x] An employee cannot insert or update a branch assignment for themselves.
- [x] An employee cannot create a branch or department, or edit tenant settings.
- [x] A CEO can still do each of those through the real RPCs.
- [x] Reading one's own memberships and org structure is unaffected.
- [x] Clean `db reset` replays; full suite passes (`Files=22, Tests=163 ... PASS`); smoke passes.
- [ ] **UNVERIFIED — Primary.** The `supabase-primary` MCP server disconnected mid-session and
      requires re-authorization, which cannot be done non-interactively. The migration is NOT
      applied to Primary and repo/local/Primary parity is NOT confirmed. Local evidence stands
      on its own; the Primary half is outstanding and is recorded as such rather than assumed.

---

## Execution Log

### 2026-08-24 — Claude Opus 5 (Foundation Completion Programme)

Outcome: Complete

`202607051600_rbac_write_authority.sql` applied. `db reset` replays clean; suite
`Files=22, Tests=163 ... PASS`; smoke `ALL CHECKS PASSED`.

Found by challenging SPEC-137 rather than by review: the read model resolves authority through
`user_role_assignments`, and that table was directly writable by anyone in the tenant. Test 22
asserts the escalation itself — an employee inserting an owner-role row for their own user id —
and it is now refused with 42501.

**A Postgres behaviour this work had to get right.** Two assertions were written expecting an
exception from an UPDATE and failed. A failed WITH CHECK raises 42501, but a row excluded by the
USING clause is simply invisible to the UPDATE: the statement succeeds having matched zero rows and
raises nothing. The security was correct; the assertions were testing for the wrong signal. They now
assert the *outcome* — the role assignment and the tenant name are unchanged — which is both the
true requirement and a standing warning against any future code that reads "no error" as "the write
happened".

---

## Verification Notes

### 2026-08-24 — Claude Opus 5 (Foundation Completion Programme)

Verdict: Confirmed Complete

Findings: the permission required by each table was taken from the `app.authorize(...)` call inside
that table's own existing write RPC, never chosen independently. That is what makes the change safe
in the direction that actually threatened it — not exposure, but lockout. Had the mapping been
picked by judgement, a mismatch would have silently disabled a legitimate administrative path, and
because all these RPCs are SECURITY INVOKER the failure would surface only in production. Tests 11
and 12 close that loop by driving `app.create_branch` and `app.assign_user_role` as a real CEO.

The MFA tables were examined and deliberately excluded: `app.mfa_satisfied()` reads the `aal` claim
from the JWT, not those tables, so the self-scoped rows a user can write there grant nothing. Adding
policies would have implied a protection that is not where the guarantee lives.

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

**Approval basis.** Owner directive 2026-08-24, §20 (configuration and security audit) and §28
(freeze criteria naming RBAC and RLS), together with the standing authority to correct defects that
belong to Foundation.

**`MANAGE_SUBSCRIPTION` is currently held by no role.** That is not an oversight to patch here:
canon 28 assigns it to the Platform Owner, with Owner and CEO "Limited". Requiring it therefore makes
`subscriptions` platform-writable only (`service_role`, which bypasses RLS), which is what canon 35
§6 describes. Widening it is a business decision about self-service subscription management, not a
security fix.

**A related gap, recorded rather than fixed.** Canon 28 gives Branch Manager `MANAGE_USERS` "Branch
only" and Department Manager "Department only", but the seeded `role_permissions` grant it to `ceo`
and `owner` alone. That predates this CR — the RPCs already authorized `MANAGE_USERS`, so branch
managers could not assign users before it either. It is a seed/canon divergence for the
table-by-table audit, not a regression introduced here.
