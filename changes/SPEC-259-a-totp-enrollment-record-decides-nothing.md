# Change Request — SPEC-259

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Record Batch 6 Slice 37's audit of `totp_enrollments` with no schema change and no new finding. The record consists of:

- one small permanent adversarial test. It proves the enrollment record decides nothing, and it adds the tripwire AUTH-1's retirement trigger lacked: any function, view, policy or trigger that starts to read the table turns the suite red;
- the surface's `AUDITED-OPEN` disposition;
- every manifest figure that this recording moves.

## Business Reason

### Selection

Boot on 2026-10-10 reported `ORVION: READY`, MODE PLAN, no active CR, and a clean tree at `d1165fb`, 0 ahead and 0 behind. `scripts/batch6_select_target.ps1` ranked `totp_enrollments` first among 41 `NOT-RECORDED` surfaces, at Exposure 8 and coverage 38, with Unguarded 1 and Direct 2. The runner-up was `subscription_payment_proofs` at 8/48. The owner directed Slice 37 to this surface.

### Authority model, measured

- **Table.** It has the canon-31 §9 columns `id`, `auth_user_id`, `is_active`, `enrolled_at`, `revoked_at` and `created_at`, and no secret column. Its FK to `auth.users(id)` cascades on delete.
- **Grants and policy.** `authenticated` holds INSERT, SELECT and UPDATE, `anon` holds nothing, and RLS is on. There is one policy, `owner_only`, for `authenticated` on every command: `auth_user_id = (select auth.uid())` in both USING and WITH CHECK.
- **Consumers.** There are no triggers, and no function in any schema, view or other policy names the table, locally or on Primary (read-only, 0 rows).
- **Step-up.** `app.mfa_satisfied()` reads `app.requires_mfa()` and the JWT `aal` claim and nothing else. `app.requires_mfa()` names `owner`, `ceo`, `finance_manager` and `system_administrator`, which are exactly canon 28's four TOTP roles. The definition md5 `e084071e938b7e897da84c3938b19950` is equal locally and on Primary.
- **Factor store.** Supabase Auth's `auth.mfa_factors` holds the secret, and neither `authenticated` nor `anon` can read it.

### The canonical authentication contract holds

- **Canon 20.** It requires authenticator-app TOTP for the four high-risk roles. ADR-0017 and canon 34 supersede its mechanics: auth artifacts live in Supabase Auth, and ORVION enforces the policy through the `aal` claim. Rolled back on the local stack: an `owner` at `aal1` fails step-up, and `app.authorize('MANAGE_TENANT_SETTINGS')` refuses it with `multi-factor authentication required for this role`.
- **Canon 34 §7.** It puts the secret and the enrollment with the Human Identity. The table holds no secret, and its rows are keyed to the human.
- **AUTH-1.** The owner decided on 2026-09-01 that Supabase Auth is the sole MFA/OTP/TOTP source and that ORVION builds no second factor-state machine. AUTH-1 owes the retirement of the unused table "before the first client-facing authentication build, or before any code first references either table". Neither has happened.

### Reproduced, and classified

Rolled back on the local stack at `d1165fb`, with the actor proven (`current_user = authenticated`, `auth.uid()` resolved). The subject of the record can:
- plant an active enrollment backdated to 2001;
- hold two active enrollments at once;
- set `is_active` true beside a `revoked_at`.

This is IDENT-3's recorded behaviour. Canon 29's "one active TOTP Enrollment" is therefore not held by this table.

It is not a finding, because the record decides nothing, measured in both directions:
- two planted active enrollments leave the owner's `app.mfa_satisfied()` false at `aal1`;
- with every own enrollment revoked, it stays true at `aal2`.

OTP-2 already reached this conclusion by derivation on 2026-09-08. The cardinality canon 29 describes belongs to a record AUTH-1 retires, and the authoritative factor store is Supabase Auth's.

### Held

- Another human's enrollment is invisible, and cannot be revoked, backdated or taken over (the WITH CHECK refuses with 42501). A cross-identity INSERT is refused with the same error for an existing and a non-existent human, so there is no existence oracle (`58_...` pins the INSERT).
- DELETE has no grant, and `anon` is refused by privilege.

### What is not protected today

`75_...` assertion 25 fails when a WRITER function appears or the grant moves. `106_...` assertion 14 pins the grant. Nothing fails when a READER appears.

The day a function, view or policy starts deciding from `totp_enrollments`, the self-plantable `is_active` becomes a forgeable authorization artifact. A rolled-back mutant shows it: with `app.mfa_satisfied()` also accepting an active row, the backdated plant satisfies step-up at `aal1`.

AUTH-1's trigger exists to stop exactly that, and today it is prose only. One assertion makes it executable for this table.

### EARN IT and WORTH IT

- **No new finding is earned.** Every behaviour above already has an owner: IDENT-3, OTP-2 and AUTH-1.
- **No repair is admitted.**
  - **A revoke** would defend nothing that reads the table, and would pre-empt AUTH-1's retirement with a partial one.
  - **A cardinality constraint or lifecycle trigger** would build the second factor-state machine AUTH-1 rejected.
  - **Retirement now** is AUTH-1's engineering task, on its own trigger, and would amend canon 29, 31, 33 and 34.
- **The test is earned.** It is one aimed file. It gives the surface an `ADVERSARIAL` disposition (Checks 22 and 24), pins the business inertness behaviourally rather than by reading text, and adds the one missing tripwire.

### Design challenge: who owns each TOTP guarantee

At the owner's direction, this Draft was challenged against current authoritative references before freezing:
- RFC 6238;
- NIST SP 800-63B-4 §§3.1.4.2, 3.2.2 and 4.1.2.1;
- the OWASP MFA Cheat Sheet;
- Supabase's MFA, TOTP and rate-limit documentation;
- the Supabase Auth server source, `internal/api/mfa.go`.

**Guarantees Supabase Auth holds.** ORVION does not rebuild any of these (AUTH-1). Each is INFERRED from the official documentation or source, not exercised here, because TOTP enrollment and verification are disabled in the local `supabase/config.toml`.
- **Secret.** The TOTP secret is generated and held in `auth.mfa_factors`, and neither `authenticated` nor `anon` can read it (PROVEN locally).
- **Algorithm.** Codes are SHA1, 6 digits, a 30 s period and one step of skew, which are RFC 6238's defaults.
- **Challenges.** A challenge is single-use, bound to the requesting IP, and expires.
- **Enroll and unenroll.** Enrolling a further factor once one is verified needs `aal2` ("AAL2 required to enroll a new factor"), and so does unenrolling a verified one. That answers OTP-2's original question at the real factor store.
- **Sessions.** Verification promotes the session to `aal2` and signs out the user's other sessions.
- **Rate limits.** The MFA challenge and verify endpoints are limited to 15 requests a minute per IP.

**Guarantees ORVION holds:**
- **Which roles need step-up.** `app.requires_mfa()` resolves live role assignments, so a grant or revocation takes effect on the next call (`99_...`).
- **That step-up is charged.** `app.authorize` checks permission, then `app.mfa_satisfied()`, for the same tenant resolution. With one human as `owner` in one tenant and `employee` in another, the permission and the MFA requirement followed the same tenant, by default and with either tenant forced (PROVEN, rolled back).
- **That the claim cannot be forged from the API.** `request.jwt.claims` is set by PostgREST from the verified JWT. The exposed schemas are `public` and `graphql_public`, no function in `app` or `public` sets it, and the two `authenticated`-callable functions that run dynamic SQL bind caller values with `USING`.

**Gaps against NIST and OWASP that sit in Supabase Auth, outside this table.** INFERRED, not reproduced, and not this contract's to repair. They are recorded so they surface before a client-facing authentication build, which is also AUTH-1's trigger:
- **No per-factor limit on failed verifications.** Supabase limits per IP only, and NIST §3.2.2 requires at most 100 consecutive failures per authenticator.
- **No record of TOTP codes already used.** A code may be accepted again with a fresh challenge from the same session and IP within its window, while NIST §3.1.4.2 requires each OTP to be accepted once.
- **The first factor can be enrolled at `aal1`.** A high-risk role holder who has never enrolled can bind a factor with the password alone, and a password thief can do the same. NIST §4.1.2.1 permits that binding at AAL1 for an AAL1-only account, but requires an out-of-band notification. Supabase's `mfa_factor_enrolled` notification is not enabled locally, and Primary's setting cannot be read with the tools available.
- **Unenrolling does not end `aal2` at once.** The claim lasts until the access token is refreshed (`jwt_expiry` 3600 locally).

**Simplification applied.** A prototype assertion pinning that `owner_only` is the table's only policy was removed:
- `75_...` already pins its USING and WITH CHECK;
- an added permissive policy for `authenticated` fails assertion 7;
- an added `anon` policy fails assertion 11.

The plan went from 17 to 16, and every mutant is still killed.

### Secondary objective: the 132-minute Migration CI observation

This was a read-only check of GitHub's own record for run `38063899253` (main, `d1165fb`, attempt 1):
- created 15:30:37Z;
- job `supabase db reset (migrations apply cleanly)` started 15:30:39Z and completed 15:34:19Z, success;
- that is 2 s queued and 3 min 40 s executing, equal to the candidate's 3.7 min.

The 132 minutes was the local watcher's elapsed time, consistent with the workstation's reported sleep. The observation is closed as explained, with no finding, CR, report or optimization task.

## Risks

- **The tripwire is read as forbidding a reader.** It forbids an unreviewed one. Its failure points at AUTH-1, which decides between retiring the table and designing its write path. Either answer changes this file deliberately.
- **The test fails when the underlying controls change.** That is its purpose. Each refusal is pinned to its own message, and the mutation restores `app.mfa_satisfied()` byte for byte.
- **A restated figure is left stale.** Mitigated: a tree-wide search found exactly two current restatements each of the coverage and suite figures, and each has its own step: the disposition record's Coverage, the manifest's Batch 6 coverage line, and the manifest suite figure.
- **Deployment risk: none.** No schema, grant, policy, trigger or function changes, and Primary is not written.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-259-a-totp-enrollment-record-decides-nothing.md`
- `supabase/tests/151_a_totp_enrollment_record_decides_nothing_test.sql`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607042900_create_authentication_support_tables.sql`
- `supabase/migrations/202607043300_create_rls_policies.sql`
- `supabase/migrations/202607056100_write_grants_match_the_writers.sql`
- `supabase/migrations/202607061600_a_challenge_its_own_subject_could_answer.sql`
- `supabase/migrations/202607061700_a_device_record_its_own_subject_could_rewrite.sql`
- `supabase/tests/58_write_grants_and_config_capability_test.sql`
- `supabase/tests/67_care_capability_and_message_integrity_test.sql`
- `supabase/tests/75_human_identity_family_test.sql`
- `supabase/tests/106_otp_challenge_subject_authority_test.sql`
- `supabase/tests/107_trusted_device_record_integrity_test.sql`
- `reports/evidence/primary-ledger-evidence.json`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/20_authentication_security_model.md`
- `_ORVION_CANONICAL/29_relationship_map.md`
- `_ORVION_CANONICAL/31_schema_draft.md`
- `_ORVION_CANONICAL/34_authentication_and_identity_principles.md`
- `supabase/config.toml`
- `scripts/verify_database.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/20_authentication_security_model.md` (High-Risk Role Login, supersession banner); `_ORVION_CANONICAL/34_authentication_and_identity_principles.md` §7; `_ORVION_CANONICAL/29_relationship_map.md` (User To TOTP Enrollment); `_ORVION_CANONICAL/31_schema_draft.md` §9; `_ORVION_CANONICAL/28_permissions_matrix.md` (TOTP roles)
- `reports/master/MASTER_GAP_REGISTER.md` (AUTH-1, IDENT-3, OTP-2, ADMIN-3, PAR-5); `reports/master/MASTER_SURFACE_DISPOSITION.md` (`totp_enrollments`, `trusted_devices`, Coverage)
- Current local `public.totp_enrollments` grants, policy and triggers; `app.mfa_satisfied`, `app.requires_mfa`, `app.authorize`
- `supabase/tests/58_write_grants_and_config_capability_test.sql`, `supabase/tests/75_human_identity_family_test.sql` (assertion 25), `supabase/tests/106_otp_challenge_subject_authority_test.sql` (assertion 14), `supabase/tests/107_trusted_device_record_integrity_test.sql` (assertion 15)

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- github

## Additional Verification

- `pwsh -NoProfile -File scripts/verify_role_journeys.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A new pgTAP file, `151_a_totp_enrollment_record_decides_nothing_test.sql`, plan 16 | `npx supabase test db`; Check 24; Check 15 | WRITE | The file with SHA-256 `84e9ca2399ecabfb3f782892cfb00a5b2821b438e59aa8c5d15b9da2b8834e73` (10425 bytes, 153 LF lines, ASCII, no CR) passed 16/16 alone on the local stack at `d1165fb`, left 0 rows, and left `app.mfa_satisfied()` at md5 `e084071e938b7e897da84c3938b19950`. It declares all ten attack classes, seven of them `N/A` with reasons, and carries `throws_ok`, so Check 24 admits `totp_enrollments` as `ADVERSARIAL` on a file aimed at it. With this file and Steps 2-4 applied in a scratch worktree at `d1165fb`, on a stack reset from the main checkout, and in `-Finish`'s own order, results were: clean reset exit 0; Pass A `Files=151, Tests=2794, Result: PASS`; `verify_role_journeys.ps1` `122 passed, 0 failed`; Pass B `Files=151, Tests=2794, Result: PASS`; `verify_database.sql` `ALL CHECKS PASSED`; 0 `totp_enrollments` rows and `app.mfa_satisfied()` `e084071e…` afterwards (4.7 min). With this contract also present: `check_database_parity_evidence.ps1` `CLEAN`; repository consistency `CLEAN`, with Check 24 reporting `all 38 surface(s) recorded ADVERSARIAL carry a declaring test file with negative assertions`; `git diff --check` exit 0. |
| The suite's size, `150 files / 2778 assertions` | manifest line `Live state`; Check 15 | WRITE | With the new file the tree holds 151 files whose literal `plan(N)` values sum to 2794, as measured on the prototype. Step 4 moves the figure only after re-confirming both numbers. The HTTP figure (464 across six scripts) is not re-measured and does not move. |
| Batch 6 coverage, 37 → 38 of 78 | `MASTER_SURFACE_DISPOSITION.md` Coverage (Checks 22, 24); manifest line `Batch 6 surface coverage` | WRITE | The Master record is the SSOT and moves in Step 2; the manifest restates it and moves in Step 3. Only `totp_enrollments` is newly dispositioned, so the count moves by exactly one, `AUDITED-OPEN` from 18 to 19, and `NOT-RECORDED` from 41 to 40. A tree-wide search found no other current restatement of `37 of 78` or `thirty-seven`; the Slice 36 freshness entry is history and stays. |
| `totp_enrollments` disposition | `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24 | WRITE | Findings `IDENT-3, OTP-2, AUTH-1`: each already has a register entry, so Check 22 resolves them, and none is opened, changed or closed. The session pointer resolves to this contract. |
| The Gap Register | `MASTER_GAP_REGISTER.md` | UNAFFECTED | No row is added or changed. AUTH-1, IDENT-3 and OTP-2 already describe every behaviour measured. The new tripwire enforces AUTH-1's existing trigger and decides nothing new. |
| Existing pins on this table | `58_...`, `67_...`, `75_...` assertion 25, `106_...` assertion 14, `107_...` assertion 15 | VERIFY | Unchanged and still passing in the prototype's full suite. Their wording records the slice that wrote them, and the register owns OTP-2's status, so they are not relabelled (Notes). |
| The generated API surface | `MASTER_API_CONTRACT.md`; `check_database_parity_evidence.ps1` Check L3 | VERIFY | No database object changes. On the prototype, the generator reproduced it with no content diff (80 RPC endpoints, 8 views, 74 tables). It is regenerated in Step 4, and an identical result is recorded. |
| The recorded Primary reading | `reports/evidence/primary-ledger-evidence.json`; Check 19; `check_database_parity_evidence.ps1` | UNAFFECTED | No migration is authored and Primary is not written. The DATABASE profile validates the recorded reading. |
| CI-only guard self-tests | `scripts/test_*_guard.ps1` (four) | VERIFY | On the prototype worktree with Steps 1-4 applied and the final test bytes, all four exited 0 in 11.0 min: `test_future_date_guard` (2.7 min), `test_status_contradiction_guard` (3.6 min), `test_primary_ledger_guard` (0.3 min) and `test_cold_start_state_guard` (4.4 min). They read the register, the disposition record, dated entries and the ledger, so they apply to this record-only slice. Step 5 runs them again on the committed state. |
| Every other surface's disposition and finding | both Master records | UNAFFECTED | `trusted_devices`, `otp_challenges` and every other row keep their rows. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| New test passes on a clean reset, in Pass A and Pass B | BEFORE_COMPLETION | NONE | NONE | Step 5 |
| Manifest suite figure equals the files and plan sum | BEFORE_COMPLETION | Step 1 | Step 4 | Step 5 |
| Manifest Batch 6 coverage equals the disposition record | BEFORE_COMPLETION | Step 2 | Step 3 | Step 5 |
| `totp_enrollments` disposition resolves its session pointer and findings, and holds `ADVERSARIAL` by a declaring file | BEFORE_COMPLETION | NONE | NONE | Step 5 |
| `ai-map.json` agrees with the manifest by value | BEFORE_COMPLETION | NONE | NONE | Step 5 |
| The four CI-only guard self-tests pass | BEFORE_COMPLETION | NONE | NONE | Step 5 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: None of the controls that govern this record is added or changed:
- the `owner_only` policy;
- `authenticated`'s missing DELETE grant and `anon`'s missing grants;
- `app.mfa_satisfied()`, which decides step-up from the JWT `aal` claim (AUTH-1).

`75_...` assertion 25 already pins the writer half of the dormancy. The new file pins the reader half and the business inertness.

Added Property: The enrollment record is executable as a record that decides nothing, so the suite turns red when that stops being true:
- a planted, backdated or duplicated active enrollment does not satisfy step-up at `aal1`;
- revoking every own enrollment does not withdraw it at `aal2`;
- another human's enrollment cannot be seen, revoked, backdated or taken over;
- no function, view, other table's policy or trigger names the table, so the first reader fails here before it can trust a self-written row.

Causal Negative: The rolled-back mutant `app.mfa_satisfied()` also accepts an active `totp_enrollments` row for the caller. With it installed, the owner's backdated plant satisfies step-up at `aal1`, and the tripwire returns `function:app.mfa_satisfied`. The table's current dormancy is therefore what keeps the self-written record harmless, and the tripwire is what notices when that ends.

Positive Test Design:
- One tenant, with an `owner`: a live member with an active `owner` role, which `app.requires_mfa()` names. A second human has an active enrollment.
- The controls prove that the owner requires MFA and that, at `aal1`, it has not satisfied it.
- The owner's plant of two active enrollments, one backdated to 2001, succeeds. That is the open door `75_...` already pins, and the precondition the business assertions judge.
- At `aal2`, with every own enrollment revoked, `app.mfa_satisfied()` is true.

Negative Test Design:
- **Business:** the plant does not satisfy step-up at `aal1`, and `app.authorize('MANAGE_TENANT_SETTINGS')` is refused 42501 with `multi-factor authentication required for this role`.
- **Auth:** the other human's enrollment reads 0 rows; handing one's own enrollment to them is refused 42501 with `new row violates row-level security policy for table "totp_enrollments"`; their row reads `true/2026-01-01` after a revoke-and-backdate attempt.
- **Door:** DELETE is refused 42501 with `permission denied for table totp_enrollments`.
- **Anon:** a read is refused 42501 with the same message.

Non-Empty Population Obligation: The owner resolves to a live member with an active high-risk role, so `app.requires_mfa()` is true and no step-up result is a dead session. The other human's row exists before every cross-identity assertion. The plant lands two rows before the business assertions judge them.

Mutation Obligation: In the file, assertions 13-16 record the `app.mfa_satisfied()` definition md5. Inside a savepoint they:
1. install the reading mutant and prove by md5 that it is installed;
2. prove that the reactivated plant passes step-up at `aal1`;
3. prove that the tripwire names `function:app.mfa_satisfied`;
4. roll back, and prove the definition md5-identical to the recorded original.

Out of file, for each mutant: install it inside the test's own transaction, prove its installation, run the file, and record the failing assertions. A mutant whose installation is not proven is a harness error, never a kill.

| Mutant | Change | Failed on the prototype |
| --- | --- | --- |
| M1 | a view reading the table | 12, 15 |
| M2 | a trigger on the table | 12, 15 |
| M3 | another table's policy reading it | 12, 15 |
| M4 | DELETE granted to `authenticated` | 10, and 14 because the row is gone |
| M5 | `anon` granted SELECT with a policy | 11 |
| M6 | `owner_only` opened to `true` | 7, 8, 9, and 14 because the row was handed away |

M2's first attempt used `app.forbid_mutation()`, which refused the fixture's own INSERT. That was recorded as a harness error and rerun with `suppress_redundant_updates_trigger()`. Afterwards the stack read `app.mfa_satisfied()` `e084071e…`, 0 views, 0 triggers and the original ACL.

Post-Implementation Proof Obligation: All of the following exit 0 on the final bytes:
- **Before `-Finish`:** the four CI-only guard self-tests.
- **Through canonical `-Finish`:**
  - a clean reset;
  - pgTAP Pass A;
  - `verify_role_journeys.ps1`;
  - pgTAP Pass B;
  - `scripts/verify_database.sql`;
  - `check_database_parity_evidence.ps1`;
  - repository consistency;
  - `git diff --check`.

## Implementation Steps

1. **Check** that `supabase/tests/151_a_totp_enrollment_record_decides_nothing_test.sql` is absent. If absent, create it as one LF, transaction-rolled-back pgTAP file with `select plan(16);` and first line `-- ATTACK-CLASSES: AUTH DOOR BUSINESS TENANT=N/A STATE=N/A INPUT=N/A CONCURRENCY=N/A OBSERVABILITY=N/A PRIVILEGE=N/A REPLAY=N/A`.
   - **Header.** It cites SPEC-259, AUTH-1, IDENT-3 and OTP-2, and states each `N/A` reason.
   - **Assertions:**
     - 1-6: the business controls and assertions;
     - 7-11: the human boundary, DELETE and `anon`;
     - 12: the tripwire;
     - 13-16: the Mutation Obligation.
   - **Exact bytes.** The file with SHA-256 `84e9ca2399ecabfb3f782892cfb00a5b2821b438e59aa8c5d15b9da2b8834e73` satisfies this step.

   If the target exists with different content, stop.
2. **Check** whether `reports/master/MASTER_SURFACE_DISPOSITION.md`'s `totp_enrollments` row reads `NOT-RECORDED`. If so:
   - **Row.** Set it to `AUDITED-OPEN` / `ADVERSARIAL` / `SPEC-259-a-totp-enrollment-record-decides-nothing` / `IDENT-3, OTP-2, AUTH-1`. The Next cell:
     - names `151_a_totp_enrollment_record_decides_nothing_test.sql` and what it proves, with mutants M1-M6;
     - states why the row is `AUDITED-OPEN`: the self-written record is benign only while nothing reads it, and AUTH-1's retirement stays owed on its own trigger, now executable here;
     - lists the swept non-defects: no secret, and `auth.mfa_factors` unreadable by `authenticated` and `anon`; canon 20 enforced through `aal`; `app.requires_mfa()` equal to canon 28's TOTP roles; canon 29's cardinality on an inert record; TOTP events owned by Supabase Auth (ADMIN-3); `service_role`'s privileges owned by the platform (PAR-5).
   - **Coverage.** Update it to `38 of 78 recorded · 16 AUDITED · 19 AUDITED-OPEN · 3 PARTIAL · 0 EXEMPT · 40 NOT-RECORDED` and `All 38 recorded surfaces`.
   - **Freshness entry.** Add a dated Slice 37 entry and demote the previous one to `Previously:`.

   Change no other row. If the row carries any other disposition, stop.
3. **Check** whether `_ORVION_CANONICAL/manifest.md` reads `Batch 6 surface coverage: **37 of 78 surfaces have a recorded audit disposition**, all thirty-seven at`. If so, change exactly that text to `Batch 6 surface coverage: **38 of 78 surfaces have a recorded audit disposition**, all thirty-eight at`. Do this only after Step 2 has set `totp_enrollments` to `AUDITED-OPEN` / `ADVERSARIAL` and the disposition record's Coverage reads `38 of 78 recorded`. Change nothing else on that line. If the line carries any other count, stop.
4. **Check** whether `_ORVION_CANONICAL/manifest.md` reads `Suite **150 files / 2778 assertions**`. If it does:
   - Confirm that `supabase/tests` holds 151 `.sql` files whose literal `plan(N)` values sum to 2794. If either number differs, stop.
   - Change only that figure to `Suite **151 files / 2794 assertions**`.
   - Regenerate `ai-map.json` with `pwsh -NoProfile -File scripts/generate-ai-map.ps1` and store it LF.
   - Regenerate `reports/master/MASTER_API_CONTRACT.md` with `pwsh -NoProfile -File scripts/generate-api-contract.ps1`, recording whether it is byte-identical. Never hand-edit it.

   If the manifest carries any other suite figure, stop.
5. **Check** for a `Local certification` Execution Log entry. If absent:
   - **Guard self-tests.** Run the four `scripts/test_*_guard.ps1` on the committed Steps 1-4 and require each to pass.
   - **Local certification.** Set Runtime Checkpoint DONE. Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`. Record each verification's exit and the pgTAP totals.
   - **Review.** Independently review the committed implementation against every Acceptance Criterion, under `## Verification Notes`.
   - **Close.** After `Verdict: Confirmed Complete`:
     - transition Complete;
     - set `Last Completed` to SPEC-259 and `Next capability` to Batch 6 Slice 38, ranked by `scripts/batch6_select_target.ps1`;
     - clear `Active Change Request`;
     - regenerate `ai-map.json` LF.
   - **Publish and certify.**
     - Prove the committed range with `-Gate -BaseRef origin/main`.
     - Publish the exact committed candidate and require exact-SHA candidate CI.
     - Promote the same accepted SHA.
     - Run `-Certify` for `REMOTE_CERTIFY: READY`.
     - Verify synchronized clean refs and remove permitted scratch files.

   Do not start Slice 38.

## Acceptance Criteria

- [ ] `supabase/tests/151_a_totp_enrollment_record_decides_nothing_test.sql` exists with SHA-256 `84e9ca2399ecabfb3f782892cfb00a5b2821b438e59aa8c5d15b9da2b8834e73`. It:
  - declares `plan(16)` and the ten attack classes;
  - pins that a planted active enrollment does not satisfy step-up at `aal1`, and revoked ones do not withdraw it at `aal2`;
  - pins the human boundary, DELETE and `anon` to their messages or rows;
  - carries the tripwire, with the reading mutant proven installed, named, and restored md5-identical.
- [ ] `MASTER_SURFACE_DISPOSITION.md` records `totp_enrollments` as `AUDITED-OPEN` / `ADVERSARIAL` / `SPEC-259-a-totp-enrollment-record-decides-nothing` / `IDENT-3, OTP-2, AUTH-1`. Coverage reads 38 of 78, with 16 `AUDITED`, 19 `AUDITED-OPEN` and 40 `NOT-RECORDED`, and no other row changed.
- [ ] `_ORVION_CANONICAL/manifest.md`'s Batch 6 surface coverage line reads `**38 of 78 surfaces have a recorded audit disposition**, all thirty-eight at` `ADVERSARIAL`, equal to the disposition record's Coverage.
- [ ] The manifest's suite figure reads `151 files / 2794 assertions`, and `ai-map.json` agrees with the manifest by value and is stored LF. `MASTER_API_CONTRACT.md` is byte-identical to its generator's output.
- [ ] The four CI-only guard self-tests pass, and `-Finish` reports `LOCAL_CERTIFY: READY`.
- [ ] `MASTER_GAP_REGISTER.md` is unchanged.
- [ ] No file under `supabase/migrations/` changed, and no database object was created, altered or dropped. Primary was not written, and Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

None yet.

### 2026-10-10 — Gate 1 approval and execution started

- **Authority:** the owner's SPEC-259 Gate 1 approval of 2026-10-10 for Draft `09be09534c3ba28dc912055ab54d3decff39332f`, contract SHA-256 `d70a5045eed1fdaf33903692bb54c2965938df0d3ad4ac89c7655e16a18a4d30` and test 151 SHA-256 `84e9ca2399ecabfb3f782892cfb00a5b2821b438e59aa8c5d15b9da2b8834e73`. It covers the record-only contract, the 16-assertion test, the `AUDITED-OPEN` disposition, and the declared documentation and generated-artifact synchronization. Verified before acting: HEAD was that commit, the tree was clean, the contract file hashed to that value, and the frozen test file in the scratch worktree and the scratchpad hashed to the test value. Approval was committed at `0d39e06`; the pre-commit Gate exited 0, and the pre-approval evaluator, re-run read-only, returned `PASS` on profiles `DATABASE, REPOSITORY`.
- **Preconditions:** test 151 is absent, and the `totp_enrollments` row reads `NOT-RECORDED`. The register, disposition record, API contract, migrations and Primary evidence file are unchanged since `d1165fb`.
- **Publication range:** before this commit, `origin/main..HEAD` held 2 commits, with 0 merges and 0 behind.
- **What the tripwire detects, stated exactly (owner's review).** Assertion 12 reads the catalog. It names:
  - every function in `app` or `public` whose `prosrc` contains `totp_enrollments`;
  - every view in `pg_views` whose definition does;
  - every policy on another table whose USING or WITH CHECK does;
  - every non-internal trigger on the table.

  It does not see:
  - application, Edge Function or n8n code that reads the table through the API. Today `supabase/functions` contains no `totp` reference.
  - a function in another schema. Today the 483 function definitions in `supabase/migrations` are all in `app` or `public`.
  - a SQL-standard `BEGIN ATOMIC` body. PROVEN, rolled back on the local stack: such a function stores an empty `prosrc` (`prosqlbody` holds the body), so the scan misses it. No migration uses the form today.
  - a materialized view, or SQL that assembles the name at run time.

  The Objective's "any function, view, policy or trigger" is read with that boundary. The approved text is not changed. The disposition row states the boundary.
- **AUTH-1 stays binding (owner's review).** This test detects the first database reader, and it replaces no part of AUTH-1. The retirement is still owed before the first client-facing authentication build, or before any code first references either table, whichever comes first. The Draft already says so in Business Reason, Risks and Step 2.
- **The four Supabase Auth concerns stay UNPROVEN.** These are the per-factor failure limit, the used-code record, first-factor enrollment at `aal1`, and `aal2` outliving an unenroll. They are outside this contract and are not ORVION findings. The execution plan has no client-facing-login gate of its own, so AUTH-1, whose trigger is that build, is the existing readiness authority. The disposition row, which cites AUTH-1, points to Business Reason, so they surface at that trigger. The register is out of this Write Scope, so no backlog entry is added or duplicated.
- **Worktrees.** Read-only inventory, nothing modified:
  - `wt251` (`578f3fb`) and `owt/p2` (`7fe62ed`) are clean.
  - `wt255` (`33e4db6`) shows 6 porcelain entries and `C:\w234` (`6c48fbb`) shows 15. Both stay untouched.
  - `wt259` holds only this contract's prototype bytes. Its results are prototype evidence, never certification, and it is removed at the end.
- **No Primary or Secondary write** is authorized or required. Secondary is never contacted.

### 2026-10-10 — Steps 1-4 applied

- **Step 1.** Test 151 was absent, and was written from the frozen bytes: SHA-256 `84e9ca2399ecabfb3f782892cfb00a5b2821b438e59aa8c5d15b9da2b8834e73`, `plan(16)`.
- **Step 2.** The `totp_enrollments` row was `NOT-RECORDED` and now reads `AUDITED-OPEN` / `ADVERSARIAL` / this contract / `IDENT-3, OTP-2, AUTH-1`. Coverage reads `38 of 78 recorded · 16 AUDITED · 19 AUDITED-OPEN · 3 PARTIAL · 0 EXEMPT · 40 NOT-RECORDED`, and the Slice 37 freshness entry is added. The Next cell also states:
  - the tripwire's exact detection boundary, as recorded above;
  - that the test replaces none of AUTH-1's retirement;
  - where the four UNPROVEN Supabase Auth concerns are recorded.

  No other row changed.
- **Step 3.** The manifest coverage line now reads `38 of 78` and `thirty-eight`.
- **Step 4.** The tree holds 151 test files whose `plan(N)` values sum to 2794, and the manifest suite figure now reads `151 files / 2794 assertions`.
  - `ai-map.json` was regenerated and stored LF.
  - `generate-api-contract.ps1` reproduced `MASTER_API_CONTRACT.md` byte-identical (80 RPC endpoints, 8 reporting views, 74 tables), so it is unchanged.
- **Checks.** `git diff --check` exit 0. `check_repository_consistency.ps1`: `REPOSITORY CONSISTENCY: CLEAN`.
## Verification Notes

None.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created or deleted.
- [ ] No section was added, removed or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

**EARN IT.** A finding needs an authoritative invariant, reproducible behaviour, a material consequence, actual ownership and non-duplication. The self-written record reproduces, but it has no consequence while nothing reads it, and it already has three owners. What was missing was a control: a reader-side tripwire for the trigger AUTH-1 already decided.

**WORTH IT.** Recording costs one 16-assertion file, one row and the figures those move. There is no migration and no Primary write.

**Rejected alternatives:**
- **Revoke INSERT and UPDATE (OTP-1's shape).** It matches the rule `75_...` states ("a write grant is kept exactly where a sanctioned writer needs it"), but it defends no behaviour today. It would also turn AUTH-1's whole retirement into a partial one, and reverse `202607056100` §3's recorded choice without the proof IDENT-3 asked for. If AUTH-1's trigger fires, the retirement decides it.
- **Retire the table now.** That is AUTH-1's engineering task, on its own trigger. It would amend canon 29, 31, 33 and 34 and four existing tests, and neither half of the trigger has occurred.
- **Enforce one active enrollment, or `is_active`/`revoked_at` coherence.** That builds the second factor-state machine AUTH-1 rejected, on a record nothing reads.
- **Require TOTP specifically, rather than any `aal2`.** Canon 20's mechanics are superseded by ADR-0017 and canon 34, which enforce the policy through `aal`. Phone MFA is disabled in `supabase/config.toml`.
- **Relabel `67_...` and `106_...`, whose descriptions still call OTP-2 open.** Their text records the slice that wrote them, and the register, which owns status, says OTP-2 was resolved. A label edit changes no assertion and would widen this contract into two more files. The disposition row for `otp_challenges` carries the same historical wording and is likewise not this slice's row.
- **Add an HTTP probe.** The pgTAP file runs as `authenticated` with JWT claims, which is PostgREST's own path, and `verify_role_journeys.ps1` already drives the four high-risk roles at `aal2` over HTTP.
- **Close the Supabase-side gaps here.** That means per-factor attempt limits through the MFA verification hook, used-code tracking, enrollment notifications, or a first-factor enrollment policy for high-risk roles. Each is Supabase Auth configuration or a hook under AUTH-1, not this table, and none has been reproduced, because TOTP is disabled locally. Reproducing them needs a `supabase/config.toml` change, which no contract authorizes yet. They are recorded in Business Reason for the owner to commission.
- **Record with no test.** Check 22 requires `ADVERSARIAL`, and the reader-side tripwire would stay missing.

**CI timing.** The main-branch Migration CI duration is explained by GitHub's own timestamps (Business Reason) and needs no further action.

**Worktrees.** Prototyping used one detached scratch worktree at `d1165fb`, with database resets from the main checkout. `wt251`, `wt255`, `C:\w234` and `owt/p2` are untouched.
