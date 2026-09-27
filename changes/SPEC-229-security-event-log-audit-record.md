# Change Request — SPEC-229

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Record Batch 6 Slice 27's audit of `security_events` with no schema change and no finding. The record consists of:

- one small permanent adversarial test that pins the security log's long-lived read and immutability controls;
- the surface's `AUDITED` disposition;
- every manifest figure that this recording moves.

## Business Reason

Batch 6 Slice 27 selected `security_events` live at Exposure 9, coverage 34; `tasks` was runner-up at 9/56. Both passes ran in rolled-back local transactions on a stack at `da2ca21` (231 migrations, latest `20260927120000`). Primary was not contacted, and Secondary was never contacted.

- **Authority model.**
  - `authenticated` holds SELECT only. `anon` holds nothing. `service_role` holds REFERENCES, TRIGGER and TRUNCATE locally and all seven privileges on Primary; it is deliberately unmanaged (PAR-5) and NOLOGIN.
  - Read: `audit_read` admits `tenant_id = app.current_tenant_id()` and `app.has_tenant_wide_read()` (VIEW_ALL_BRANCHES, held by `owner` and `ceo` by default). `202607052200` chose this on purpose: the log is restricted to tenant-wide readers outright rather than dispatched by subject.
  - Write: no `authenticated` door. `202607053000` revoked INSERT to close a proven forgery (a colleague framed with a backdated `login_failure`) and kept the `audit_insert` policy, now inert, on purpose.
  - Immutability: `security_events_append_only`, BEFORE UPDATE OR DELETE, calls `app.forbid_mutation()` for every role.
  - Producers: four SECURITY DEFINER functions. `platform_issue_license_token`, `platform_revoke_license_tokens` and `platform_review_payment_proof` are `service_role`-only. `redeem_license_token` is `authenticated`, charges `app.authorize('MANAGE_TENANT_SETTINGS')`, and stamps tenant and actor from the session, never from an argument.
  - Consumers: no function, view, policy or trigger reads the table.
- **Pass A (actor matrix and mutations).**
  - A tenant-wide reader sees its own tenant's event, and neither another tenant's nor a platform (`tenant_id` null) event. An ordinary employee of the same tenant sees none. `anon` is refused by privilege.
  - The reader's UPDATE, DELETE and INSERT are each refused `permission denied for table security_events`.
  - As table owner, UPDATE and DELETE are refused `append-only table: … is not permitted on security_events`.
  - Removing `audit_read`'s tenant-wide-reader conjunct let the employee read the log. Removing its tenant conjunct let the owner read the other tenant's and the platform's events. Each conjunct is therefore its leak's only refuser.
  - Granting UPDATE/DELETE to `authenticated` with permissive policies was still refused by the trigger. With the trigger also disabled, the UPDATE landed. The trigger is therefore the owner of immutability for any role that holds the grant and bypasses RLS, as `service_role` does on Primary.
  - Every mutation was installed, proven, rolled back and proven restored (policy md5 `2cce8be9b298dd7a02e52015b803bd3b`, two policies, no UPDATE/DELETE grant, trigger enabled).
- **Pass B (related rows that could change the same fact).** The fact is "this security action happened, in this tenant, by this actor". The actor's identity is `users`' own binding (`users_enforce_identity_binding`, `users` `AUDITED-OPEN`). The type codes are system catalog rows, read by code rather than label. No related row can rewrite, move or re-attribute an event.
- **Canon.**
  - Canon 35 describes the audit tables as `INSERT` + tenant `SELECT`. The revoked INSERT is `202607053000`'s later, recorded correction, and the tables remain append-only.
  - Canon 20 lists fourteen event kinds. Fourteen of the eighteen registered types have no producer: the authentication ones are Supabase Auth events with no ORVION hook (AUTH-1, `MASTER_EXECUTION_PLAN.md` item 6), and permission changes are recorded in `events` at `security` severity (RBAC-1).
  - Canon 20 binds TOTP to high-risk roles because they "perform high-risk financial or administrative operations", and ADR-0017 enforces it through `aal` on sensitive RPCs. None of the database's 128 policies (124 on `public`) charges step-up or `app.authorize`.
- **EARN IT: no new finding earned.**
  - **An `aal1` reader is not a finding.** An `aal1` owner reads the log. That is schema-wide read posture, not STEPUP-1's criterion (a direct permission-only write path), and the payload holds no credential (`43_...`).
  - **Already owned elsewhere:** `service_role`'s TRUNCATE (PAR-5, and no PostgREST verb reaches it), the unproduced authentication types (AUTH-1, EVT-2), refused redemptions not being audited (LIC-1), and the concurrent double redemption (LIC-2).
  - **The inert `audit_insert` policy is INTENTIONAL**, recorded by `202607053000`.
- **WORTH IT: no repair admitted because there is no earned finding.**
- **Why a permanent test is still earned.**
  - The read gate is a deliberate `202607052200` decision with two single-refuser conjuncts, and no file exercises it. `10_...` pins only the SELECT-only grant, `34_...` the forged INSERT, `02_...` only that a `forbid_mutation` trigger exists (not that it fires on UPDATE and DELETE), and `43_...` the producers' emissions.
  - On Primary the trigger is the only control between `service_role` and a rewritten security history.
  - EC-6 requires targeted negative tests on security-sensitive surfaces.
  - Check 22 requires every recorded surface to stand at `ADVERSARIAL`, and no existing file naming `security_events` declares attack classes, so Check 24 needs an aimed file.

## Risks

- **An audit is mistaken for a pinned `aal1` read.** Mitigated: the test runs its readers at `aal2`, and its header states that the `aal1` read is deliberately not pinned in either direction.
- **The test fails when the underlying controls change.** That is its purpose. It pins only the read gate and immutability, each by its own message or row set.
- **A restated figure is left stale.** Mitigated: each restatement found by a tree-wide search has its own step. Those are the disposition Coverage, the manifest's Batch 6 coverage line and the manifest suite figure.
- **Deployment risk: none.** No schema, grant, policy, trigger, function or Primary write is made.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-229-security-event-log-audit-record.md`
- `supabase/tests/133_security_event_log_authority_test.sql`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607042600_create_event_and_notification_tables.sql`
- `supabase/migrations/202607043300_create_rls_policies.sql`
- `supabase/migrations/202607043400_grant_authenticated_access_and_memberships.sql`
- `supabase/migrations/202607052200_event_visibility_and_timelines.sql`
- `supabase/migrations/202607053000_event_write_path_integrity.sql`
- `supabase/migrations/202607054100_tenant_license_activation.sql`
- `supabase/tests/02_append_only_audit_test.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/34_event_write_path_test.sql`
- `supabase/tests/43_license_activation_test.sql`
- `supabase/tests/132_tenant_row_authority_test.sql`
- `reports/evidence/primary-ledger-evidence.json`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/20_authentication_security_model.md`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/35_tenant_isolation_and_data_access_principles.md`
- `scripts/verify_database.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/20_authentication_security_model.md` (High-Risk Role Login; Security Events); `_ORVION_CANONICAL/35_tenant_isolation_and_data_access_principles.md` (append-only audit); `_ORVION_CANONICAL/34_authentication_and_identity_principles.md` (platform-level security events)
- Current local `public.security_events` columns, grants, policies and triggers; `app.forbid_mutation`, `app.has_tenant_wide_read`, `app.has_permission`, `app.redeem_license_token`, `app.platform_issue_license_token`, `app.platform_revoke_license_tokens`, `app.platform_review_payment_proof`
- `supabase/migrations/202607052200_event_visibility_and_timelines.sql` and `supabase/migrations/202607053000_event_write_path_integrity.sql` (headers)
- `supabase/tests/02_append_only_audit_test.sql`, `supabase/tests/10_grant_model_test.sql`, `supabase/tests/34_event_write_path_test.sql`, `supabase/tests/43_license_activation_test.sql`
- `reports/master/MASTER_SURFACE_DISPOSITION.md` (`security_events`, Coverage); `reports/master/MASTER_GAP_REGISTER.md` (PAR-5, AUDIT-6, LIC-1, LIC-2, GOV-6, STEPUP-1)

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- github

## Additional Verification

- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`

## Pre-Approval Evidence

Change Class: Routine

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A new pgTAP file, `133_security_event_log_authority_test.sql`, plan 14 | `npx supabase test db`; Check 24; Check 15 | WRITE | The file with SHA-256 `e2e37ded12a596f87fedf9a735b7f8da4c9e27d24461de0e47c64c6601a56ad5` (LF) passed 14/14 alone on the local stack at `da2ca21`. The run left 0 residue, and the `audit_read` md5 stayed `2cce8be9b298dd7a02e52015b803bd3b`. It declares all ten attack classes, seven of them `N/A` with reasons, and carries `throws_ok`, so Check 24 admits `security_events` as `ADVERSARIAL` on a file aimed at it. With this file and Steps 2-4 applied in a scratch worktree at `da2ca21`, and in `-Finish`'s own order, results were: clean reset exit 0; Pass A `Files=133, Tests=2378, Result: PASS`; `verify_journey_branches.ps1` `74 passed, 0 failed`; Pass B `Files=133, Tests=2378, Result: PASS`; `verify_database.sql` `ALL CHECKS PASSED`; `check_database_parity_evidence.ps1` `CLEAN`; repository consistency with a single issue, the session pointer to this not-yet-present contract (Check 22), and Check 24 reporting `all 28 surface(s) recorded ADVERSARIAL carry a declaring test file with negative assertions`; `git diff --check` exit 0. Those prototype pgTAP runs set `SUPABASE_TELEMETRY_DISABLED` and `DO_NOT_TRACK` for their own process. |
| The suite's size, `132 files / 2364 assertions` | manifest line `Live state`; Check 15 | WRITE | With the new file the tree holds 133 files whose literal `plan(N)` values sum to 2378, as measured on the prototype, where Check 15 reported the figure matching. Step 4 moves the figure only after re-confirming both numbers. The HTTP figure (449 across six scripts) is not re-measured and does not move. |
| Batch 6 coverage, 27 → 28 of 77 | `MASTER_SURFACE_DISPOSITION.md` Coverage (Checks 22, 24); manifest line `Batch 6 surface coverage` | WRITE | The Master record is the SSOT and moves in Step 2; the manifest restates it and moves in Step 3. Only `security_events` is newly dispositioned, so the count moves by exactly one, and `AUDITED` moves from 9 to 10. A tree-wide search found no other current restatement of `27 of 77` or `twenty-seven`; the disposition record's Slice 26 freshness entry is history and stays. |
| `security_events` disposition | `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24 | WRITE | Findings `—`: no finding is earned, and Check 22 resolves nothing. The session pointer resolves to this contract. |
| The Gap Register | `MASTER_GAP_REGISTER.md` | UNAFFECTED | No row is added or changed. Every classification above cross-references an existing owner (PAR-5, AUTH-1, EVT-2, LIC-1, LIC-2, RBAC-1, AUDIT-6), and STEPUP-1 is not reached because this surface has no `authenticated` write path. |
| The generated API surface | `MASTER_API_CONTRACT.md`; `check_database_parity_evidence.ps1` Check L3 | VERIFY | No database object changes. On the prototype, the generator reproduced it with no content diff (79 RPC endpoints, 8 views, 73 tables). It is regenerated in Step 4, and an identical result is recorded. |
| The recorded Primary reading | `reports/evidence/primary-ledger-evidence.json`; Check 19; `check_database_parity_evidence.ps1` | UNAFFECTED | No migration is authored and Primary is not written. The DATABASE profile validates the recorded reading, so a fresh read is not mechanically required. |
| Every other surface's disposition and finding | both Master records | UNAFFECTED | `tenant_license_activations`, `subscription_payment_proofs` and `events` keep their rows. STEPUP-1, PAR-5, LIC-1, LIC-2, CAP-1, SUB-3 and USR-3 are unchanged. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| New test passes on a clean reset, in Pass A and Pass B | BEFORE_COMPLETION | NONE | NONE | Step 5 |
| Manifest suite figure equals the files and plan sum | BEFORE_COMPLETION | Step 1 | Step 4 | Step 5 |
| Manifest Batch 6 coverage equals the disposition record | BEFORE_COMPLETION | Step 2 | Step 3 | Step 5 |
| `security_events` disposition resolves its session pointer and holds `ADVERSARIAL` by a declaring file | BEFORE_COMPLETION | NONE | NONE | Step 5 |
| `ai-map.json` agrees with the manifest by value | BEFORE_COMPLETION | NONE | NONE | Step 5 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: The security log is already governed by existing controls, and none is added or changed. The test pins those controls:
- the `audit_read` policy and its two conjuncts;
- `authenticated`'s missing UPDATE and DELETE grants;
- the `security_events_append_only` trigger and `app.forbid_mutation()`.

Added Property: The security log's long-lived read and immutability controls are executable in the permanent suite, so a regression in any of them turns the suite red. These are:
- a tenant-wide reader sees only its own tenant's events, never another tenant's or a platform event;
- an ordinary employee cannot browse the tenant's security log;
- the reader who can see an event cannot rewrite or delete it;
- a role holding the grant and bypassing RLS still cannot rewrite or delete an event.

Causal Negative: In rolled-back local transactions, an ordinary employee read the tenant's security event once `audit_read`'s tenant-wide-reader conjunct was removed, and a tenant-wide owner read another tenant's and a platform event once its tenant conjunct was removed. With UPDATE granted and a permissive policy added, the owner's rewrite was still refused until the trigger was disabled, when it landed.

Positive Test Design: The owner at `aal2` is a tenant-wide reader and sees exactly its own tenant's event. The employee is a live member of the same tenant.

Negative Test Design: Four statements are refused, each by its own message:
- the reader's UPDATE: `permission denied for table security_events`;
- the reader's DELETE: the same message;
- the table owner's UPDATE: `append-only table: UPDATE is not permitted on security_events`;
- the table owner's DELETE: `append-only table: DELETE is not permitted on security_events`.

The employee sees no event. Afterwards, all three events survive unchanged.

Non-Empty Population Obligation: The owner is a tenant-wide reader and sees its own tenant's event, and the employee resolves to the same tenant, so no empty read is a dead session. Another tenant's event and a platform event exist.

Mutation Obligation: Removing either `audit_read` conjunct inside a savepoint must open exactly its leak, and the restore must be byte-identical.
1. Record `audit_read`'s USING md5.
2. Inside a savepoint, replace it without the tenant-wide-reader conjunct, prove by md5 that the mutant is installed, prove the employee reads one event, and roll back.
3. Inside a savepoint, replace it without the tenant conjunct, prove by md5 that the mutant is installed, prove the owner reads all three events, and roll back.
4. Prove that the expression is md5-identical to the recorded original.

A mutant whose installation is not proven is a harness error, never a killed mutant.

Post-Implementation Proof Obligation: The following all exit 0 on the final bytes, through canonical `-Finish`:
- a clean reset;
- pgTAP Pass A;
- `verify_journey_branches.ps1`;
- pgTAP Pass B;
- `scripts/verify_database.sql`;
- `check_database_parity_evidence.ps1`;
- repository consistency;
- `git diff --check`.

## Implementation Steps

1. **Check** that `supabase/tests/133_security_event_log_authority_test.sql` is absent. If absent, create it as one LF, transaction-rolled-back pgTAP file with `select plan(14);` and first line `-- ATTACK-CLASSES: TENANT PRIVILEGE DOOR AUTH=N/A STATE=N/A INPUT=N/A BUSINESS=N/A CONCURRENCY=N/A REPLAY=N/A OBSERVABILITY=N/A`.
   - **Header.** It cites SPEC-229 and states each `N/A` reason. It names what other files already pin (`34_...`, `10_...`, `02_...`, `43_...`) and states that an `aal1` reader is deliberately not pinned in either direction.
   - **Assertions:**
     - 1-4: the Non-Empty Population Obligation, the Positive Test Design and the employee's empty read;
     - 5-9: the Negative Test Design;
     - 10-14: the Mutation Obligation.
   - **Exact bytes.** The file with SHA-256 `e2e37ded12a596f87fedf9a735b7f8da4c9e27d24461de0e47c64c6601a56ad5` satisfies this step.

   If the target exists with different content, stop.
2. **Check** whether `reports/master/MASTER_SURFACE_DISPOSITION.md`'s `security_events` row reads `NOT-RECORDED`. If so:
   - **Row.** Set it to `AUDITED` / `ADVERSARIAL` / `SPEC-229-security-event-log-audit-record` / `—`. The Next cell:
     - names `133_security_event_log_authority_test.sql` and what it proves, including the two mutation-proven conjuncts and the trigger as the only control for a role holding the grant and bypassing RLS (PAR-5);
     - states `No finding`;
     - lists the swept non-defects (the forged INSERT closed by the revoked grant and `34_...`, with the inert `audit_insert` recorded by `202607053000`; the four SECURITY DEFINER producers, three `service_role`-only, and session-stamped redemption; no reader of the table; `service_role`'s TRUNCATE under PAR-5 with no PostgREST verb; the 14 unproduced types owned by AUTH-1 or recorded in `events` by RBAC-1; actor identity owned by `users`);
     - states that an `aal1` reader is deliberately not pinned, because no policy charges step-up on a read and the payload holds no credential.
   - **Coverage.** Update it to `28 of 77 recorded · 10 AUDITED · 15 AUDITED-OPEN · 3 PARTIAL · 0 EXEMPT · 49 NOT-RECORDED` and `All 28 recorded surfaces`.
   - **Freshness entry.** Add a dated Slice 27 entry and demote the previous one to `Previously:`.

   Change no other row. If the row carries any other disposition, stop.
3. **Check** whether `_ORVION_CANONICAL/manifest.md` reads `Batch 6 surface coverage: **27 of 77 surfaces have a recorded audit disposition**, all twenty-seven at`. If so, change exactly that text to `Batch 6 surface coverage: **28 of 77 surfaces have a recorded audit disposition**, all twenty-eight at`. Do this only after Step 2 has set `security_events` to `AUDITED` / `ADVERSARIAL` and the disposition record's Coverage reads `28 of 77 recorded`. Change nothing else on that line. If the line carries any other count, stop.
4. **Check** whether `_ORVION_CANONICAL/manifest.md` reads `Suite **132 files / 2364 assertions**`. If it does:
   - Confirm that `supabase/tests` holds 133 `.sql` files whose literal `plan(N)` values sum to 2378. If either number differs, stop.
   - Change only that figure to `Suite **133 files / 2378 assertions**`.
   - Regenerate `ai-map.json` with `pwsh -NoProfile -File scripts/generate-ai-map.ps1` and store it LF.
   - Regenerate `reports/master/MASTER_API_CONTRACT.md` with `pwsh -NoProfile -File scripts/generate-api-contract.ps1`, recording whether it is byte-identical. Never hand-edit it.

   If the manifest carries any other suite figure, stop.
5. **Check** for a `Local certification` Execution Log entry. If absent:
   - **Local certification.** Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`. Record each verification's exit and the pgTAP totals. If a run fails only because the Supabase CLI times out flushing its telemetry after the suite itself printed `Result: PASS`, it may be retried once with `SUPABASE_TELEMETRY_DISABLED` and `DO_NOT_TRACK` set for that process only, and both attempts are recorded. Any other failure is not retried this way.
   - **Review.** Independently review the committed implementation against every Acceptance Criterion.
   - **Close.** After `Verdict: Confirmed Complete`:
     - set Runtime Checkpoint DONE and transition Complete;
     - set `Last Completed` to Slice 27 and `Next capability` to Batch 6 Slice 28, ranked by `scripts/batch6_select_target.ps1`;
     - clear `Active Change Request`;
     - regenerate `ai-map.json` LF.
   - **Publish and certify.**
     - Prove the committed range with `-Gate -BaseRef origin/main`.
     - Publish the exact committed candidate and require exact-SHA candidate CI.
     - Promote the same accepted SHA.
     - Run `-Certify` for `REMOTE_CERTIFY: READY`.
     - Verify synchronized clean refs and remove permitted scratch files.

   Do not start Slice 28.

## Acceptance Criteria

- [ ] `supabase/tests/133_security_event_log_authority_test.sql` exists with SHA-256 `e2e37ded12a596f87fedf9a735b7f8da4c9e27d24461de0e47c64c6601a56ad5`. It:
  - declares `plan(14)` and the ten attack classes;
  - states that an `aal1` reader is deliberately not pinned;
  - pins the tenant-wide reader's own-tenant-only read and the employee's empty read;
  - pins the reader's UPDATE and DELETE and the table owner's UPDATE and DELETE to their messages, with all three events unchanged;
  - mutation-proves both `audit_read` conjuncts with a byte-identical restore.
- [ ] `MASTER_SURFACE_DISPOSITION.md` records `security_events` as `AUDITED` / `ADVERSARIAL` / `SPEC-229-security-event-log-audit-record` with Findings `—`. Coverage reads 28 of 77 with 10 `AUDITED`, and no other row changed.
- [ ] `_ORVION_CANONICAL/manifest.md`'s Batch 6 surface coverage line reads `**28 of 77 surfaces have a recorded audit disposition**, all twenty-eight at` `ADVERSARIAL`, equal to the disposition record's Coverage.
- [ ] The manifest's suite figure reads `133 files / 2378 assertions`, and `ai-map.json` agrees with the manifest by value and is stored LF. `MASTER_API_CONTRACT.md` is byte-identical to its generator's output.
- [ ] `MASTER_GAP_REGISTER.md` is unchanged.
- [ ] No file under `supabase/migrations/` changed, and no database object was created, altered or dropped. Primary was not written, and Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-09-27 — Owner approval

Owner approved the exact Draft SHA `5154cd284b72af9f796f8e0df021b2658b93a0a4` and the frozen six-path Write Scope. Before the Draft was committed, a read-only evaluation of it returned `APPROVAL_EVIDENCE: PASS` (profiles DATABASE, REPOSITORY). A mutated copy with a gate inside a red window returned FAIL. Pre-approval revalidation:
- HEAD is the Draft SHA, and the tree is clean;
- `origin/main` is at `da2ca21`.

Approval authorizes the record-only Slice 27 execution only. It does not authorize a migration, schema change, Primary write, Gap Register change, new finding, or any work on PAR-5, AUTH-1, EVT-2, LIC-1, LIC-2 or STEPUP-1. The certifying `-Finish` runs first without telemetry opt-outs.

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

**EARN IT.** Every Slice 27 candidate was classified, and none is a finding. A finding needs an authoritative invariant, reproducible behaviour, a material consequence, actual ownership and non-duplication. The `aal1` read has the behaviour and nothing else. Every other candidate already has an owner. Recording therefore costs one small test aimed at controls that no file exercises, one row, and the figures those move.

**WORTH IT.** No repair is admitted, because there is no earned finding.

**Rejected alternatives:**
- **Record with no test.** Check 22 requires every recorded surface to be `ADVERSARIAL`, and no existing file naming `security_events` declares attack classes, so Check 24 would fail; the read gate would also stay unexercised.
- **Record `TESTED`.** Check 22 refuses it, and it would understate a surface that was attacked.
- **Re-pin the forged INSERT, the grant model or the producers.** `34_...`, `10_...` and `43_...` already own them; a second copy is suite cost with no new invariant.
- **Pin or refuse the `aal1` read.** No policy in the schema gates a read on step-up, so either direction would decide a schema-wide question inside one surface.
- **Drop the inert `audit_insert` policy, add a TRUNCATE guard, or build authentication-event producers.** Each is either `202607053000`'s recorded choice, PAR-5's, or AUTH-1's, and none is this slice's.
- **Add a Gap Register freshness entry.** No register fact changes.

**Untouched:** STEPUP-1, PAR-5, LIC-1, LIC-2, AUTH-1, EVT-2, CAP-1, SUB-3, USR-3 and `tenant_license_activations`. The registered worktree `owt/p2` is untouched.
