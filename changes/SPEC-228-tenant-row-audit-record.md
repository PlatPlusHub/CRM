# Change Request — SPEC-228

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Record Batch 6 Slice 26's audit of `tenants` with no schema change and no finding. The record consists of:

- one small permanent adversarial test that pins the tenant row's long-lived boundary controls;
- the surface's `AUDITED` disposition;
- the classification of STEPUP-1's `tenants` member;
- every manifest figure that this recording moves.

## Business Reason

Batch 6 Slice 26 selected `tenants` live at Exposure 10, coverage 622; `security_events` was runner-up at 9/34. Both passes ran in rolled-back local transactions on a stack at `7c80b65` (231 migrations, latest `20260927120000`). Primary was not contacted, and Secondary was never contacted.

- **Pass A (actor matrix and mutations).**
  - An `owner` or `ceo` holding MANAGE_TENANT_SETTINGS edits its own tenant row. Every other actor matched no row: a finance manager, a system administrator, an employee, a CEO carrying a deny, and another tenant's owner. An employee with a per-user grant succeeds by the RBAC-3 design.
  - `anon` is refused by privilege.
  - Creating a tenant is refused by `scope_insert`'s tenant conjunct alone. With that conjunct removed, the same owner's creation landed.
  - Moving the tenant's id is refused by WITH CHECK, `scope_read` and the inbound foreign keys.
  - A cross-tenant UPDATE is refused by two independent policies. It landed only when both were removed.
  - DELETE has no grant.
  - Status vocabulary, currency, trial stamp and slug are each refused by their own constraint or trigger.
  - `created_at` is writable.
  - No event is emitted.
- **Pass B (consumers and canon).** Nothing reads any writable `tenants` column except `name`, which `app.my_memberships` and `app.activate_membership` show only to the tenant's own members.
  - **Where this was checked:**
    - every function, view, policy, trigger and cron job;
    - the edge functions and scripts;
    - the integration catalog;
    - notification routing;
    - the n8n instance, which has 0 workflows.
  - **Canon:**
    - Canon 20 requires TOTP at login for owner, CEO, finance manager and system administrator.
    - `202607044100` charges step-up at "sensitive RPCs" through `app.authorize` and keeps `app.has_permission` pure.
    - No canon marks a tenant-profile edit as step-up, platform-only, immutable or sensitive.
    - Canon 27 defines no tenant-settings event.
- **EARN IT: no new finding earned.**
  - **STEPUP-1's `tenants` member is UNPROVEN, with no material consequence.** The `aal1` edit is reproduced, but no authority requires step-up for it and nothing reads what it changes. The other MANAGE_TENANT_SETTINGS doors that charge `app.authorize` guard distinct actions, not a second door to the same action, so this is not BRANCH-1's shape. Those actions are licence redemption, payment-proof upload, legal hold, document versions and links, and holidays.
  - **A lapsed tenant editing its own row is CLEAN.** `tenants` has no `tenant_id` and is outside the commercial write gate by construction. The gate's recorded scope keeps organization administration writable, and canon's read-only lists name business data only.
  - **The global slug is INTENTIONAL.** Canon 30 and 31 make it business-unique, and nothing reads it.
  - **`status` is CLEAN.** It is account-level and unread, and canon 35 makes the subscription the only access authority.
  - **Already owned elsewhere:** `default_currency_code` by SUP-4a, and `created_at` by SPEC-216's schema-wide question.
- **WORTH IT: no repair admitted because there is no earned finding.**
- **Why a permanent test is still earned.** Pass A showed that one policy conjunct alone stops a signed-in owner from creating a tenant, and no existing file pins it.
  - Nor does any existing file pin, for `tenants`: the cross-tenant UPDATE, moving the id, DELETE, or `anon`'s refusal.
  - `22_...` pins an employee's refused rename; `42_...` pins the trial stamp and the status vocabulary.
  - EC-6 requires targeted negative tests on security-sensitive surfaces, and the tenant row is the root of tenant isolation.
  - Check 22 requires every recorded surface to stand at `ADVERSARIAL`. Without an aimed file, Check 24 would be satisfied only by the many fixtures that insert into `tenants`, which is MEAS-1.
- **STEPUP-1** keeps Status `UNPROVEN` and its eleven-table criterion. Its trigger to revisit ("the Batch 6 slice of any listed table") has fired for `tenants`, so the sentence that calls the `tenants` consequence unclassified is replaced by the classification above. `departments` stays an unclassified candidate.

## Risks

- **An audit is mistaken for a pinned STEPUP-1 member.** Mitigated: the test runs its owner at `aal2`. Its header states that the `aal1` edit is deliberately not pinned in either direction, and the register keeps STEPUP-1 `UNPROVEN`.
- **The test fails when the underlying controls change.** That is its purpose. It pins only the boundary controls, each by its own message.
- **A restated figure is left stale.** Mitigated: each restatement found by a tree-wide search has its own step. Those are the disposition Coverage, the manifest's Batch 6 coverage line and the manifest suite figure.
- **Deployment risk: none.** No schema, grant, policy, trigger, function or Primary write is made.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-228-tenant-row-audit-record.md`
- `supabase/tests/132_tenant_row_authority_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607041600_create_organization_tables.sql`
- `supabase/migrations/202607043300_create_rls_policies.sql`
- `supabase/migrations/202607053100_subscription_state_enforcement.sql`
- `supabase/migrations/202607054000_subscription_lifecycle_and_platform_authority.sql`
- `supabase/tests/22_write_authority_test.sql`
- `supabase/tests/42_subscription_lifecycle_test.sql`
- `supabase/tests/130_branch_door_audit_test.sql`
- `supabase/tests/131_platform_authority_cannot_be_granted_test.sql`
- `reports/evidence/primary-ledger-evidence.json`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/20_authentication_security_model.md`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `_ORVION_CANONICAL/35_tenant_isolation_and_data_access_principles.md`
- `scripts/verify_database.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/20_authentication_security_model.md` (roles requiring TOTP); `_ORVION_CANONICAL/28_permissions_matrix.md` (MANAGE_TENANT_SETTINGS; read-only mode); `_ORVION_CANONICAL/35_tenant_isolation_and_data_access_principles.md` (subscription as access authority); `_ORVION_CANONICAL/27_event_catalog.md` (Organization and User Events)
- Current local `public.tenants` columns, grants, policies, constraints and triggers; `app.provision_tenant`, `app.my_memberships`, `app.activate_membership`, `app.authorize`, `app.has_permission`, `app.mfa_satisfied`, `app.requires_mfa`, `app.enforce_trial_stamp_immutable`
- `supabase/tests/22_write_authority_test.sql`, `supabase/tests/42_subscription_lifecycle_test.sql`, `supabase/tests/130_branch_door_audit_test.sql`
- `reports/master/MASTER_SURFACE_DISPOSITION.md` (`tenants`, Coverage); `reports/master/MASTER_GAP_REGISTER.md` (STEPUP-1, BRANCH-1, BRANCH-2, SUP-4a, SUB-3, USR-3, CAP-1)

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- github

## Additional Verification

- `pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1`

## Pre-Approval Evidence

Change Class: Routine

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A new pgTAP file, `132_tenant_row_authority_test.sql`, plan 13 | `npx supabase test db`; Check 24; Check 15 | WRITE | The file with SHA-256 `df45c2c90e80a65760cfdce59db7019b42bbd44a54c3e31f157065f9b62bef92` (LF) passed 13/13 alone on the local stack at `7c80b65`. The run left 0 residue, and the `tenants` policy md5 stayed `948e95144b4001b1089b83437d4ec936` before and after. It declares all ten attack classes, six of them `N/A` with reasons, and carries `throws_ok`, so Check 24 admits `tenants` as `ADVERSARIAL` on a file aimed at it. With this file, this contract and Steps 2-5 applied in a scratch worktree at `7c80b65`, a clean reset gave these results: Pass A `Files=132, Tests=2364, Result: PASS`; `verify_api_end_to_end.ps1` `33 passed, 0 failed`; Pass B `Files=132, Tests=2364, Result: PASS`; `verify_database.sql` `ALL CHECKS PASSED`; `check_database_parity_evidence.ps1` `CLEAN`; repository consistency exit 0, with Check 24 reporting `all 27 surface(s) recorded ADVERSARIAL carry a declaring test file with negative assertions`; `git diff --check` exit 0. |
| The suite's size, `131 files / 2351 assertions` | manifest line `Live state`; Check 15 | WRITE | With the new file the tree holds 132 files whose literal `plan(N)` values sum to 2364, as measured on the prototype. Step 5 moves the figure only after re-confirming both numbers. The HTTP figure (449 across six scripts) is not re-measured and does not move. |
| Batch 6 coverage, 26 → 27 of 77 | `MASTER_SURFACE_DISPOSITION.md` Coverage (Checks 22, 24); manifest line `Batch 6 surface coverage` | WRITE | The Master record is the SSOT and moves in Step 3; the manifest restates it and moves in Step 4. Only `tenants` is newly dispositioned, so the count moves by exactly one, and `AUDITED` moves from 8 to 9. A tree-wide search found no other restatement of `26 of 77` or `twenty-six`. |
| `tenants` disposition | `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24 | WRITE | Findings `—`: no finding is earned, and Check 22 resolves nothing. The session pointer resolves to this contract. |
| STEPUP-1's `tenants` sentence and a Slice 26 freshness entry | `MASTER_GAP_REGISTER.md`; Checks 2, 11, 16, 21, 25 | WRITE | No row is added. STEPUP-1's Status, severity, criterion, member list, Owner Decision `—`, Source and dates are unchanged; only the sentence naming the `tenants` consequence as unclassified is replaced. The replacement asserts no owner decision, so Check 25 adds nothing to the manifest's open-decision line. |
| The generated API surface | `MASTER_API_CONTRACT.md`; `check_database_parity_evidence.ps1` Check L3 | VERIFY | No database object changes. On the prototype, the generator reproduced it with no content diff (79 RPC endpoints, 8 views, 73 tables). It is regenerated in Step 5, and an identical result is recorded. |
| The recorded Primary reading | `reports/evidence/primary-ledger-evidence.json`; Check 19; `check_database_parity_evidence.ps1` | UNAFFECTED | No migration is authored and Primary is not written. The DATABASE profile validates the recorded reading, so a fresh read is not mechanically required. |
| Every other surface's disposition and finding | both Master records | UNAFFECTED | `departments` and the other STEPUP-1 candidates keep their rows. CAP-1, SUB-3, USR-3, BRANCH-1, BRANCH-2, BOOK-10 and SUP-4a are unchanged. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| New test passes on a clean reset, in Pass A and Pass B | BEFORE_COMPLETION | NONE | NONE | Step 6 |
| Manifest suite figure equals the files and plan sum | BEFORE_COMPLETION | Step 1 | Step 5 | Step 6 |
| Manifest Batch 6 coverage equals the disposition record | BEFORE_COMPLETION | Step 3 | Step 4 | Step 6 |
| `tenants` disposition resolves its session pointer and holds `ADVERSARIAL` by a declaring file | BEFORE_COMPLETION | NONE | NONE | Step 6 |
| `ai-map.json` agrees with the manifest by value | BEFORE_COMPLETION | NONE | NONE | Step 6 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: The tenant row is already governed by existing controls, and none is added or changed. The test pins those controls:
- the `scope_read`, `scope_insert` and `scope_update` policies;
- `authenticated`'s missing DELETE grant;
- `anon`'s missing grant;
- `app.provision_tenant` as the only creator, executable by `service_role` only.

Added Property: The tenant row's long-lived boundary controls are executable in the permanent suite, so a regression in any of them turns the suite red. These are:
- tenant creation is platform-only;
- a tenant row cannot be moved to another id;
- another tenant's row cannot be changed;
- a tenant row cannot be deleted;
- the tenant directory is not public.

Causal Negative: In rolled-back local transactions, an owner at `aal2` created a new tenant once `scope_insert`'s tenant conjunct was removed. Another tenant's owner renamed the tenant once both `scope_read` and `scope_update`'s tenant predicates were removed.

Positive Test Design: The owner at `aal2` holds MANAGE_TENANT_SETTINGS, sees exactly its own tenant row, and edits it.

Negative Test Design: Four statements are refused, each by its own message:
- the owner's creation of a tenant: `new row violates row-level security policy for table "tenants"`;
- moving its tenant's id: the same message;
- DELETE: `permission denied for table tenants`;
- `anon`'s read: `permission denied for table tenants`.

The owner's UPDATE of another tenant's row leaves it unchanged. Afterwards, no tenant was created and neither row moved.

Non-Empty Population Obligation: The owner holds MANAGE_TENANT_SETTINGS, sees its own row and edits it, so no refusal is a dead session. The other tenant exists with its own owner.

Mutation Obligation: Removing `scope_insert`'s tenant conjunct inside a savepoint must let the owner's creation land, and the restore must be byte-identical.
1. Record `scope_insert`'s WITH CHECK md5.
2. Inside a savepoint, replace it without the tenant conjunct.
3. Prove by md5 that the mutant is installed.
4. Prove that the owner's creation of a tenant lands.
5. Roll back.
6. Prove that the expression is md5-identical to the recorded original and that no mutant row survived.

A mutant whose installation is not proven is a harness error, never a killed mutant.

Post-Implementation Proof Obligation: The following all exit 0 on the final bytes, through canonical `-Finish`:
- a clean reset;
- pgTAP Pass A;
- `verify_api_end_to_end.ps1`;
- pgTAP Pass B;
- `scripts/verify_database.sql`;
- `check_database_parity_evidence.ps1`;
- repository consistency;
- `git diff --check`.

## Implementation Steps

1. **Check** that `supabase/tests/132_tenant_row_authority_test.sql` is absent. If absent, create it as one LF, transaction-rolled-back pgTAP file with `select plan(13);` and first line `-- ATTACK-CLASSES: AUTH TENANT DOOR PRIVILEGE STATE=N/A INPUT=N/A BUSINESS=N/A CONCURRENCY=N/A REPLAY=N/A OBSERVABILITY=N/A`.
   - **Header.** It cites SPEC-228 and states each `N/A` reason. It states that the `aal1` edit (STEPUP-1's `tenants` member), a lapsed tenant's edit, the global slug and a caller-supplied `created_at` are deliberately not pinned in either direction.
   - **Assertions:**
     - 1-3: the Non-Empty Population Obligation and the Positive Test Design;
     - 4-9: the Negative Test Design;
     - 10-13: the Mutation Obligation.
   - **Exact bytes.** The file with SHA-256 `df45c2c90e80a65760cfdce59db7019b42bbd44a54c3e31f157065f9b62bef92` satisfies this step.

   If the target exists with different content, stop.
2. **Check** whether `reports/master/MASTER_GAP_REGISTER.md`'s STEPUP-1 row contains `` `tenants` was audited in Batch 6 Slice 26 ``. If absent:
   - **Freshness entry.** Add a dated Slice 26 freshness entry and demote the previous entry to `Previously:`. The entry states:
     - the selection;
     - audited and clean, with no finding and no repair;
     - the `aal1` edit as STEPUP-1's `tenants` member, consequence-classified as none material, with the reason;
     - that STEPUP-1 stays UNPROVEN and gains no reproduced member;
     - the lapsed edit, slug, `status`, `default_currency_code` (SUP-4a) and `created_at` (SPEC-216), classified without a new row.
   - **STEPUP-1 row.** Replace exactly the sentence `` The same probe saw an `aal1` owner's rename land on `departments` and on `tenants`; neither consequence is classified, so both remain candidates and neither is an audit. `` with this text:

     ``The same probe saw an `aal1` owner's rename land on `departments` and on `tenants`. `departments`' consequence is not classified, so it remains a candidate and is not an audit. **`tenants` was audited in Batch 6 Slice 26 (SPEC-228) and its consequence is classified: none material.** An `aal1` `owner` or `ceo` does write every tenant-profile column, but nothing reads any of them except `name`, shown only to the tenant's own members; no canon marks a tenant-profile edit as step-up, platform-only or sensitive; and the other MANAGE_TENANT_SETTINGS doors that charge `app.authorize` guard distinct actions (licence redemption, payment-proof upload, legal hold, document versions and links, holidays), not a second door to the same action. So `tenants` still meets the criterion, is not a defect, and does not raise this class above UNPROVEN.``

   Change nothing else in that row and no other row, and add no row. If the sentence to be replaced is absent and the replacement is not present, stop.
3. **Check** whether `reports/master/MASTER_SURFACE_DISPOSITION.md`'s `tenants` row reads `NOT-RECORDED`. If so:
   - **Row.** Set it to `AUDITED` / `ADVERSARIAL` / `SPEC-228-tenant-row-audit-record` / `—`. The Next cell:
     - names `132_tenant_row_authority_test.sql` and what it proves;
     - states `No finding`;
     - lists the swept non-defects (unread writable columns except member-only `name`; unread account-level `status`; the lapsed edit outside the commercial gate by construction; the global slug; `default_currency_code` and `created_at` already owned; no canon tenant-settings event);
     - states that the `aal1` edit is STEPUP-1's `tenants` member, classified there and deliberately not pinned.
   - **Coverage.** Update it to `27 of 77 recorded · 9 AUDITED · 15 AUDITED-OPEN · 3 PARTIAL · 0 EXEMPT · 50 NOT-RECORDED` and `All 27 recorded surfaces`.
   - **Freshness entry.** Add a dated Slice 26 entry and demote the previous one to `Previously:`.

   Change no other row. If the row carries any other disposition, stop.
4. **Check** whether `_ORVION_CANONICAL/manifest.md` reads `Batch 6 surface coverage: **26 of 77 surfaces have a recorded audit disposition**, all twenty-six at`. If so, change exactly that text to `Batch 6 surface coverage: **27 of 77 surfaces have a recorded audit disposition**, all twenty-seven at`. Do this only after Step 3 has set `tenants` to `AUDITED` / `ADVERSARIAL` and the disposition record's Coverage reads `27 of 77 recorded`. Change nothing else on that line. If the line carries any other count, stop.
5. **Check** whether `_ORVION_CANONICAL/manifest.md` reads `Suite **131 files / 2351 assertions**`. If it does:
   - Confirm that `supabase/tests` holds 132 `.sql` files whose literal `plan(N)` values sum to 2364. If either number differs, stop.
   - Change only that figure to `Suite **132 files / 2364 assertions**`.
   - Regenerate `ai-map.json` with `pwsh -NoProfile -File scripts/generate-ai-map.ps1` and store it LF.
   - Regenerate `reports/master/MASTER_API_CONTRACT.md` with `pwsh -NoProfile -File scripts/generate-api-contract.ps1`, recording whether it is byte-identical. Never hand-edit it.

   If the manifest carries any other suite figure, stop.
6. **Check** for a `Local certification` Execution Log entry. If absent:
   - **Local certification.** Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`. Record each verification's exit and the pgTAP totals.
   - **Review.** Independently review the committed implementation against every Acceptance Criterion.
   - **Close.** After `Verdict: Confirmed Complete`:
     - set Runtime Checkpoint DONE and transition Complete;
     - set `Last Completed` to Slice 26 and `Next capability` to Batch 6 Slice 27, ranked by `scripts/batch6_select_target.ps1`;
     - clear `Active Change Request`;
     - regenerate `ai-map.json` LF.
   - **Publish and certify.**
     - Prove the committed range with `-Gate -BaseRef origin/main`.
     - Publish the exact committed candidate and require exact-SHA candidate CI.
     - Promote the same accepted SHA.
     - Run `-Certify` for `REMOTE_CERTIFY: READY`.
     - Verify synchronized clean refs and remove permitted scratch files.

   Do not start Slice 27.

## Acceptance Criteria

- [ ] `supabase/tests/132_tenant_row_authority_test.sql` exists with SHA-256 `df45c2c90e80a65760cfdce59db7019b42bbd44a54c3e31f157065f9b62bef92`. It:
  - declares `plan(13)` and the ten attack classes;
  - states that the `aal1` edit is deliberately not pinned;
  - pins tenant creation, id relocation, DELETE and `anon` refusal to their messages and the cross-tenant UPDATE to an unchanged row;
  - mutation-proves `scope_insert`'s tenant conjunct with a byte-identical restore.
- [ ] `MASTER_GAP_REGISTER.md` has a Slice 26 freshness entry, and STEPUP-1 keeps Status `UNPROVEN` and its criterion. Only its `tenants` sentence changed, now classifying that member's consequence as none material while `departments` stays an unclassified candidate. No row was added and no other row changed.
- [ ] `MASTER_SURFACE_DISPOSITION.md` records `tenants` as `AUDITED` / `ADVERSARIAL` / `SPEC-228-tenant-row-audit-record` with Findings `—`. Coverage reads 27 of 77 with 9 `AUDITED`, and no other row changed.
- [ ] `_ORVION_CANONICAL/manifest.md`'s Batch 6 surface coverage line reads `**27 of 77 surfaces have a recorded audit disposition**, all twenty-seven at` `ADVERSARIAL`, equal to the disposition record's Coverage.
- [ ] The manifest's suite figure reads `132 files / 2364 assertions`, and `ai-map.json` agrees with the manifest by value and is stored LF. `MASTER_API_CONTRACT.md` is byte-identical to its generator's output.
- [ ] No file under `supabase/migrations/` changed, and no database object was created, altered or dropped. Primary was not written, and Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-09-27 — Owner approval

Owner approved the exact Draft SHA `e04e2ffd34aa2cf9dfddd2b9e2c167324e7366f3` and the frozen seven-path Write Scope. Before the Draft was committed, a read-only evaluation of it returned `APPROVAL_EVIDENCE: PASS` (profiles DATABASE, REPOSITORY). A mutated copy with a gate inside a red window returned FAIL. Pre-approval revalidation:
- HEAD is the Draft SHA, and the tree is clean;
- `origin/main` is at `7c80b65`.

Approval authorizes the record-only Slice 26 execution only. It does not authorize a migration, schema change, Primary write, STEPUP-1 repair or new finding.

## Verification Notes

None yet.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created or deleted.
- [ ] No section was added, removed or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

**EARN IT.** Every Slice 26 candidate was classified, and none is a finding. A finding needs an authoritative invariant, reproducible behaviour, a material consequence, actual ownership and non-duplication. The `aal1` edit has the behaviour and nothing else. Recording therefore costs one small test aimed at controls that no file pins, one row, one sentence in STEPUP-1, and the figures those move.

**WORTH IT.** No repair is admitted, because there is no earned finding.

**Rejected alternatives:**
- **Record with no test.** Check 22 requires every recorded surface to be `ADVERSARIAL`, and Check 24 would then be satisfied only by fixtures that name `tenants`, which is MEAS-1.
- **Record `TESTED`.** Check 22 refuses it, and it would understate a surface that was attacked.
- **Pin the `aal1` edit.** That would freeze an UNPROVEN non-finding as either desired behaviour or an OPEN defect.
- **Promote, reproduce or repair STEPUP-1 or any other member.** That is scope expansion.
- **Pin slug uniqueness, the lapsed edit or `created_at`.** None has a long-lived invariant with a consequence.

**Untouched:** CAP-1, SUB-3, USR-3, BRANCH-1, BRANCH-2, BOOK-10, SUP-4a and `departments`. The registered worktree `owt/p2` is untouched.
