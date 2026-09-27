# Change Request — SPEC-227

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make `MANAGE_SUBSCRIPTION` and `REVIEW_SUBSCRIPTION_PAYMENT` impossible to grant to any tenant user through `public.user_permission_grants`, so that no tenant principal can hold the platform authority over its own subscription.

## Business Reason

Batch 6 Slice 25 selected `subscriptions` live at Exposure 10, coverage 610; `tenants` was runner-up at 10/616.

- **The intended rule.** SPEC-157 (`202607054000`) put the subscription lifecycle outside every tenant. `subscriptions` INSERT, UPDATE and DELETE require `app.has_permission('MANAGE_SUBSCRIPTION')`; deciding a payment proof (`subscription_payment_proofs.scope_update`, and the `subscription_approval` arm of `approval_requests.scope_update`) requires `REVIEW_SUBSCRIPTION_PAYMENT`; and no role holds either, so both gates deny every tenant user. Platform authority lives in SECURITY DEFINER functions that only `service_role` may execute. Canon 28 states it three times: `REVIEW_SUBSCRIPTION_PAYMENT` is `No` for Owner and CEO; "Tenant users may upload proof but cannot approve their own subscription renewal"; "`subscriptions` writes need `MANAGE_SUBSCRIPTION`, which no role holds". Canon 31 adds that the plan gate runs last "so a tenant administrator can never grant past a commercial entitlement". SPEC-157's report records why the gate must be held by no one: granting it to `owner` or `ceo` "would have let each tenant elevate its own subscription, the exact opposite of the requirement".
- **SUB-3 (High, reproduced, latent).** RBAC-3 (`202607059800`) added a second path from a user to a permission. `public.user_permission_grants` is written by any MANAGE_PERMISSIONS holder (`owner`, `ceo`) for any permission; no guard restricts which. The repository has no function that writes it, so the table is its only door.
  - **Reproduction.** Measured on a clean reset at `691178c`, in rolled-back transactions. An `owner` at `aal2` (step-up satisfied) belonged to a `read_only` starter tenant: its write gate was false, and its direct subscription UPDATE matched 0 rows. The owner inserted grants of both permissions to itself. It then:
    - rewrote its subscription to `active` / `enterprise` / `lifetime`, which turned `app.subscription_allows_write` from false to true and made the Enterprise entitlements live;
    - inserted a second, newer `active` / `enterprise` subscription row, which falsifies the "a second row is unreachable" premise of CAP-1;
    - marked its own pending payment proof `approved`, after which `app.platform_review_payment_proof` refused the Platform Owner (`payment proof is already approved, only a pending proof can be reviewed`).
  - **Observability.** The only events were two `permission_granted`; the subscription rewrite recorded nothing.
  - **Exposure.** Primary `vrvtsxexkiiiivlkdxzp` holds the same policies and 0 tenants, 0 subscriptions and 0 grants (read-only, 2026-09-27), so nobody has used this. Every future tenant's owner and CEO would be able to.
- **Why SUB-3 is not an existing finding.**
  - **USR-3** is the missing step-up at this table's door; SUB-3 reproduces at `aal2` with step-up satisfied, and repairing USR-3 would leave it untouched.
  - **SPP-3** is where a platform reviewer's identity is stored.
  - **CAP-1** is `app.tenant_capabilities`' row ordering.
  - **SUB-1** and **SUB-2** are resolved provisioning and lifecycle-date defects.
  - `42_subscription_lifecycle_test.sql` assertion 20 still passes, because it pins the role half of the mechanism only.
- **The repair** restores SPEC-157's mechanism at the one door that reopened it: "no role holds these two permissions" becomes "no tenant principal holds them". One BEFORE INSERT OR UPDATE trigger on `user_permission_grants` calls a SECURITY DEFINER function. It refuses every row whose effect is `grant` for either key, on every path including the session-less one, with `42501` and its own message. The migration first refuses to deploy if such a grant already exists.

## Risks

- A too-wide guard would break ordinary RBAC administration. Mitigated: the guard reads only `effect` and the permission key, and in the prototype an ordinary grant, a deny of either key and a revocation all still landed.
- A SECURITY INVOKER guard would break `service_role` writes, because `service_role` holds no SELECT on `public.permissions`. The function is SECURITY DEFINER with an empty `search_path` and EXECUTE revoked from PUBLIC, like `app.guard_membership_authority`.
- A pre-existing grant would stay live, because a trigger judges only new writes. Mitigated: the migration's pre-check raises instead of deciding that grant's fate; Primary and local both hold 0 such grants.
- Primary deployment adds one function and one trigger to production. It requires separate exact-byte owner authorization (Gate 2) after the local proof; this contract's approval does not authorize it.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-227-platform-authority-cannot-be-granted.md`
- `supabase/migrations/20260927120000_platform_authority_cannot_be_granted.sql`
- `supabase/tests/131_platform_authority_cannot_be_granted_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607054000_subscription_lifecycle_and_platform_authority.sql`
- `supabase/migrations/202607059800_capability_grants_are_per_user_not_only_per_role.sql`
- `supabase/migrations/202607054800_subscription_payment_proof_scope.sql`
- `supabase/tests/42_subscription_lifecycle_test.sql`
- `supabase/tests/47_payment_proof_lifecycle_test.sql`
- `supabase/tests/80_subscription_licensing_test.sql`
- `supabase/tests/92_capability_grant_model_test.sql`
- `supabase/tests/118_membership_authority_and_audit_test.sql`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `_ORVION_CANONICAL/31_schema_draft.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `scripts/verify_database.sql`
- `scripts/verify_role_journeys.ps1`
- `scripts/verify_journey_branches.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/28_permissions_matrix.md` (Subscription Permissions; Plan Gating Enforcement); `_ORVION_CANONICAL/31_schema_draft.md` (`user_permission_grants` rules)
- `reports/history/subscription-licensing-platform-authority-alignment-2026-08-27.md` (B6 and "What the Platform Owner controls this turned out to mean")
- Current local `public.user_permission_grants` policies and triggers, `public.subscriptions` and `public.subscription_payment_proofs` policies, `app.has_permission`, `app.platform_review_payment_proof`, `app.upload_subscription_payment_proof`, `app.guard_membership_authority`
- `reports/master/MASTER_SURFACE_DISPOSITION.md` (`subscriptions`, Coverage); `reports/master/MASTER_GAP_REGISTER.md` (SUB-1, SUB-2, SPP-1/SPP-2, SPP-3, CAP-1, USR-3, USR-4)

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- supabase-primary
- github

## Additional Verification

- `pwsh -NoProfile -File scripts/verify_role_journeys.ps1`
- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A grant of `MANAGE_SUBSCRIPTION` or `REVIEW_SUBSCRIPTION_PAYMENT` is refused on every write to `user_permission_grants` | the PostgREST table door (the table's only writer); `scope_insert` / `scope_update` policies; `app.derive_created_by`; `app.emit_permission_change` | VERIFY | The prototype was applied as a real migration on a clean reset in a scratch worktree at `691178c`, with migration SHA-256 `dea69945ee1549ceb95e9376dca986ca16b17b21c291fb1ab0effdbdd36d6c72` and test SHA-256 `f48d48b58027964b3913cebfe09466bdf9e50f4816524feadc3e4a52a3d40c9a`. Refused with `42501` and the guard's own message: self-grant; granting a colleague; re-pointing an ordinary grant; flipping a deny to a grant; and the session-less insert. Still landed: an ordinary grant, a deny of either key, and a revocation. `verify_role_journeys.ps1`, which grants and revokes over HTTP, passed 120, failed 0. |
| Permission resolution | `app.has_permission`; `app.effective_permissions`; every policy, trigger and function that resolves through them | UNAFFECTED | Neither function changes. With no grant row possible, both return what they return for a user holding neither key through any role; `92_capability_grant_model_test.sql` and `118_...` pass unchanged. |
| The tenant boundary on subscription state and proof review | `subscriptions` scope_insert/update/delete; `subscription_payment_proofs.scope_update`; `approval_requests.scope_update` (`subscription_approval` arm) | UNAFFECTED | No policy changes. Their deny-all, which SUB-3 defeated through a user grant, holds again. No function produces a `subscription_approval` request (0 producers measured), and the arm is covered anyway. |
| Platform and tenant subscription paths | `app.provision_tenant`; `app.platform_activate_subscription`; `app.platform_transition_subscription`; `app.platform_review_payment_proof`; `app.process_subscription_lifecycle`; `app.upload_subscription_payment_proof`; licence redemption | VERIFY | None reads or writes `user_permission_grants`. Tests 35, 36, 42, 47 and 80 pass unchanged; `verify_journey_branches.ps1` (licensing and payment proof over HTTP) passed 74, failed 0; test 131 proves the platform still decides a proof the tenant could not touch. |
| Rows that already exist | Primary and local `user_permission_grants` | VERIFY | The migration's pre-check raises if a forbidden grant exists. Primary read-only on 2026-09-27: 0 grants of any kind, 0 forbidden, 0 tenants. The clean local reset had 0 before the suite ran. |
| Suite, smoke and every other HTTP door | full pgTAP; `scripts/verify_database.sql`; the other four HTTP suites | VERIFY | On the candidate stack: pgTAP Pass A 131 files / 2351 assertions PASS (2320 existing assertions unchanged, plus 31 new); HTTP 33 + 120 + 40 + 74 + 122 + 60 = 449 passed, 0 failed; Pass B without reset 131 / 2351 PASS; smoke `ALL CHECKS PASSED`, exit 0. |
| The generated API surface | `MASTER_API_CONTRACT.md`; `check_database_parity_evidence.ps1` Check L3 | VERIFY | The generator run against the candidate stack to a scratch file is byte-identical to the committed contract (79 RPC endpoints, 8 views, 73 tables). It is regenerated in Step 7 and any difference is recorded. |
| Measured state that moves | manifest (`Live state`, suite figure, Batch 6 coverage, Last Completed, Active pointer); `primary-ledger-evidence.json`; `ai-map.json`; Checks 5, 7, 15, 19, 22, 24 | WRITE | 230 → 231 migrations, latest `20260927120000`, 130 → 131 files / 2320 → 2351 assertions, coverage 25 → 26 of 77. Primary values are written only from fresh post-deploy readings. The manifest is 6707 of its 7000-character budget; the Approve pointer fits, and Step 7 keeps each moved line within its current length or trims `Last Completed`. |
| Findings and disposition | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 2, 11, 16, 21, 22, 25 | WRITE | One new row, SUB-3, with Owner Decision `—` (Check 25 adds nothing to the open-decision line). Only the `subscriptions` row changes, to `AUDITED` / `ADVERSARIAL`, because after the repair no tenant door writes any subscription state. CAP-1, USR-3 and every other row are unchanged. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused test, pgTAP A/B, both declared HTTP suites, smoke and in-file mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| SUB-3 and the `subscriptions` disposition accurately describe local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite figure equals the files and plan sum | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| Manifest Batch 6 coverage equals the disposition record | BEFORE_COMPLETION | Step 3 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: SPEC-157's control is that no role holds the two permissions, and `42_...` assertion 20 pins it. It governs `role_permissions`, which tenants cannot write. It does not govern the per-user path RBAC-3 added. No existing guard asks which permission a grant names:
- `app.guard_write_capability` charges the capability needed to write a table, and `user_permission_grants` is already gated by MANAGE_PERMISSIONS in RLS;
- teaching `app.has_permission` to ignore these keys would put a second rule into the single decision point every policy, guard and RPC resolves through;
- revoking `authenticated`'s writes on `subscriptions` would leave the grant live and reported by `app.effective_permissions`, would not reach proof review, and would break `42_...`'s direct-UPDATE assertion.

So one table-local trigger in `app.guard_membership_authority`'s shape (BEFORE, SECURITY DEFINER, empty `search_path`, EXECUTE revoked from PUBLIC) is added. It is not a framework: two named keys, one table.

Added Property: No row in `user_permission_grants` can ever carry effect `grant` for `MANAGE_SUBSCRIPTION` or `REVIEW_SUBSCRIPTION_PAYMENT`, on any path. So no tenant user can hold either permission, and subscription state and payment-proof decisions stay platform-only. Ordinary grants, denies of either key, revocations and every platform function keep their behaviour.

Causal Negative: On a clean reset at `691178c`, in rolled-back transactions, an `owner` at `aal2` on a `read_only` starter tenant granted itself both permissions and then:
- moved its subscription to `active` / `enterprise` / `lifetime`, opening its write gate;
- inserted a second subscription row;
- approved its own pending payment proof, after which the platform review was refused.

Positive Test Design: As the owner at `aal2`: a lapsed tenant uploads its renewal proof; an ordinary grant lands; a deny of `REVIEW_SUBSCRIPTION_PAYMENT` lands; an ordinary grant is revoked. As the platform (session-less): `app.platform_review_payment_proof` decides the untouched proof.

Negative Test Design: Five writes are refused with `42501` and `permission denied: <KEY> is platform authority and cannot be granted to a tenant user`: the owner's self-grant of `MANAGE_SUBSCRIPTION`; the owner's grant of `REVIEW_SUBSCRIPTION_PAYMENT` to an employee; re-pointing an ordinary grant; flipping a deny to a grant; and a session-less grant. After them:
- no forbidden grant exists;
- the owner's direct subscription rewrite leaves `read_only:starter` and the write gate closed;
- the owner's direct proof approval leaves it `pending`;
- a second subscription row is refused `new row violates row-level security policy for table "subscriptions"`;
- another tenant's subscription is invisible, and an employee sees none;
- `authenticated` cannot execute the three platform functions and holds no DELETE on `subscriptions`.

Non-Empty Population Obligation: The tenant is `read_only` with its write gate closed. The owner holds MANAGE_PERMISSIONS, holds neither platform permission, can see its subscription, and has a pending proof. Each refused write targets that tenant, that user or a visible row.

Mutation Obligation: Record the guard function's `pg_get_functiondef` md5, then open a savepoint and disable `user_permission_grants_guard_platform_authority`. Prove `tgenabled = 'D'`. As the same owner, grant both permissions and prove that the subscription reads `active:enterprise:lifetime`, the write gate is open and the proof is `approved`. Roll back to the savepoint, then prove `tgenabled = 'O'`, the md5 is unchanged, and no mutant grant or rewrite survived. A mutant whose installation is not proven is a harness error, never a killed mutant.

Post-Implementation Proof Obligation: Focused test, clean reset, pgTAP Pass A, both declared HTTP suites, pgTAP Pass B, smoke, the in-file mutation, generated artifacts, fresh Primary evidence, parity evidence, the Primary ledger check, repository consistency and `git diff --check`, all on the final bytes and through canonical `-Finish`.

## Implementation Steps

1. **Check** that `supabase/migrations/20260927120000_platform_authority_cannot_be_granted.sql` is absent. If absent, create it LF with SHA-256 `dea69945ee1549ceb95e9376dca986ca16b17b21c291fb1ab0effdbdd36d6c72`. That file contains:
   - a pre-check that raises if any `user_permission_grants` row has effect `grant` for either key;
   - `app.guard_platform_permission_grant()` (plpgsql, SECURITY DEFINER, `search_path` empty), which raises `42501` `permission denied: % is platform authority and cannot be granted to a tenant user` for such a row and returns `new` otherwise;
   - `revoke all ... from public` and a comment;
   - trigger `user_permission_grants_guard_platform_authority` BEFORE INSERT OR UPDATE FOR EACH ROW.

   It changes no policy, grant, permission, role or existing function. If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/131_platform_authority_cannot_be_granted_test.sql` is absent. If absent, create it LF with SHA-256 `f48d48b58027964b3913cebfe09466bdf9e50f4816524feadc3e4a52a3d40c9a`: one transaction-rolled-back pgTAP file with `select plan(31);` and first line `-- ATTACK-CLASSES: AUTH DOOR PRIVILEGE TENANT BUSINESS STATE OBSERVABILITY REPLAY=N/A INPUT=N/A CONCURRENCY=N/A`. Its header cites SPEC-227 and states each `N/A` reason. It implements:
   - the Non-Empty Population Obligation (1-5);
   - the Negative and Positive Test Design (6-22, 31);
   - the attachment (23);
   - the Mutation Obligation (24-30).

   If the target exists with different bytes, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` contains `| SUB-3 |`. If absent:
   - Add a dated Slice 25 freshness entry and demote the previous entry to `Previously:`.
   - Append one row after `| STEPUP-1 |`: **SUB-3**, Category `security · authorization · revenue`, Sev `High`, Req/Opt `R`, Batch `6`, Mig `A`, Cert `📋`, Owner Decision `—`, Source `SPEC-227-platform-authority-cannot-be-granted`, dates `09-27`. Its Status reads `FIXED locally by SPEC-227 (`20260927120000`), pending Primary deployment` and states:
     - the reproduction and consequence above;
     - latent exposure (0 tenants on Primary);
     - why it is not USR-3, SPP-3, CAP-1, SUB-1 or SUB-2;
     - that CAP-1's "unreachable" premise was false while SUB-3 stood and holds again once it is repaired;
     - that the mechanism is pinned by `131_...`.
   - Change no other row.

   Then check whether `reports/master/MASTER_SURFACE_DISPOSITION.md`'s `subscriptions` row reads `NOT-RECORDED`. If so:
   - Set it to `AUDITED` / `ADVERSARIAL` / `SPEC-227-platform-authority-cannot-be-granted` / `SUB-3`. Its Next cell names `131_platform_authority_cannot_be_granted_test.sql` and what it proves. It also states the swept non-defects: tenant isolation and read permission held; no DELETE grant; the platform functions are not executable by `authenticated`; status and period codes are catalog-enforced and lifetime by CHECK; direct-write event parity has no tenant door after the repair; CAP-1 remains separately recorded on `app.tenant_capabilities`.
   - Update Coverage to `26 of 77 recorded · 8 AUDITED · 15 AUDITED-OPEN · 3 PARTIAL · 0 EXEMPT · 51 NOT-RECORDED` and `All 26 recorded surfaces`.
   - Add a dated freshness entry and demote the previous one to `Previously:`.
   - Change no other row.

   If either target already carries different content, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 hashes:
   - a clean local reset and the focused test;
   - pgTAP Pass A, both declared HTTP suites, then pgTAP Pass B without reset;
   - `scripts/verify_database.sql` and the plan sum;
   - the in-file mutation evidence;
   - the API-contract and map generators;
   - the scope check, `git diff --check` and repository consistency.

   Treat only undeployed Primary, manifest and parity drift as expected at this boundary. Read a fresh Primary baseline, read-only:
   - full ordered ledger;
   - function and structural surfaces;
   - forbidden grant count;
   - tenant count;
   - absence of the target migration, function and trigger.

   Record the predicted structural delta.
5. **Check** that exact owner authorization for the migration and Test-131 SHA-256 values is recorded in the Execution Log. If absent, stop after Step 4 and present:
   - the current HEAD;
   - the exact 64-character hashes;
   - the fresh Primary baseline and the predicted delta;
   - the exact Primary write requested.

   Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20260927120000_platform_authority_cannot_be_granted`. If it is absent and deployment is separately authorized:
   - Immediately re-read: HEAD; both hashes; the project URL; the full ordered ledger; target absence; the forbidden grant count (must be 0); and the absence of the function and trigger.
   - On an exact match, apply only the authorized migration through the Primary connector. If the connector assigns a temporary version, normalize only its newly inserted ledger row.
   - Read fresh: the ledger, the function surface and all ten structural surfaces, the new function's definition, security mode, `search_path` and EXECUTE ACL, and the trigger's timing and enabled state.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set the `Live state` migration count, latest version, ledger and surface hashes and counts from the same readings, and the suite figure to `Suite **131 files / 2351 assertions**` after confirming `supabase/tests` holds 131 files whose literal `plan(N)` values sum to 2351 (if either differs, stop).
   - Change the Batch 6 line's `**25 of 77 surfaces have a recorded audit disposition**, all twenty-five at` to `**26 of 77 surfaces have a recorded audit disposition**, all twenty-six at`, only after Step 3 set Coverage to `26 of 77 recorded`.
   - Set `Last Completed` to Slice 25 / SUB-3 / SPEC-227, trimming it so the manifest stays within 7000 characters.
   - Mark SUB-3 `FIXED` and `DEPLOYED` in the register and change its Cert to `✅`.
   - Regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` (stored LF) with the canonical generators, never by hand.
   - Run `check_primary_ledger.ps1`, `check_database_parity_evidence.ps1`, repository consistency and `git diff --check`.

   If Primary is unproven, stop.
8. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, set Runtime Checkpoint DONE, transition Complete, set `Next capability` to Batch 6 Slice 26 ranked by `scripts/batch6_select_target.ps1`, clear `Active Change Request` and regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate and require exact-SHA candidate CI. Promote the same accepted SHA, run `-Certify` for `REMOTE_CERTIFY: READY`, verify synchronized clean refs and remove permitted scratch files.

   Do not start Slice 26.

## Acceptance Criteria

- [ ] No write to `public.user_permission_grants` on any path can create or leave a row with effect `grant` for `MANAGE_SUBSCRIPTION` or `REVIEW_SUBSCRIPTION_PAYMENT`. Each refusal (self-grant, colleague grant, re-point, deny-to-grant flip, session-less) is pinned to `42501` and the guard's own message.
- [ ] With the guard installed, an `owner` at `aal2` on a lapsed tenant cannot change its subscription's state, plan or period, cannot add a subscription row and cannot decide its own payment proof. With the guard disabled in a savepoint, the same actor does all three, and the restored guard is enabled and byte-identical.
- [ ] Ordinary grants, denies of either key, revocations, proof upload, platform proof review, `app.has_permission`, every policy and every existing function keep their behaviour; `verify_role_journeys.ps1` and `verify_journey_branches.ps1` pass.
- [ ] SUB-3 is registered High and `FIXED` / `DEPLOYED`. `subscriptions` is `AUDITED` / `ADVERSARIAL` with finding SUB-3. Coverage reads 26 of 77 in both the disposition record and the manifest. CAP-1, USR-3 and every other row are unchanged.
- [ ] The migration and Test 131 match their authorized SHA-256 values. Primary, the recorded evidence, the manifest (231 migrations; 131 files / 2351 assertions), the API contract and `ai-map.json` agree.
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and no business-data write, and Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-09-27 — Owner approval

Owner approved the exact Draft SHA `c1052c4bacbe54f151ebf65cb6592d3edea90120` and the frozen nine-path Write Scope. A read-only evaluation of the committed Draft returned `APPROVAL_EVIDENCE: PASS` (profiles DATABASE, REPOSITORY), and two mutated copies of it returned FAIL (a gate inside a red window) and INDETERMINATE (Mutation Obligation removed). Pre-approval revalidation:
- HEAD `c1052c4`; `origin/main` and `origin/orvion-preflight` at `691178c`; clean tree; `npx supabase status` and `npx supabase db reset` exit 0.
- Primary `vrvtsxexkiiiivlkdxzp`, read-only: 230 / `be85ed1e62f6504e9b04171677d32bc8`, latest `20260926140000`; 0 tenants, 0 subscriptions, 0 grants, 0 forbidden grants; no guard function.

Review hypotheses resolved on the local stack before execution. The approved design is unchanged:
- **Acquisition paths.** `app.has_permission` resolves only user grants and role grants. `permissions`, `roles` and `role_permissions` are SELECT-only for `authenticated`, and no function writes them. Roles are global. `assign_user_role`, `revoke_user_role` and direct `user_role_assignments` assign only existing roles, none of which holds either key. So `user_permission_grants` is the only acquisition path, and permission identity is platform-owned.
- **Security mode.** A SECURITY INVOKER variant broke a legitimate `service_role` ordinary grant (`permission denied for table permissions`), because `service_role` has no SELECT on `permissions`. DEFINER is therefore earned. Owner `postgres`, `search_path` empty, every object qualified, no dynamic SQL; EXECUTE false for PUBLIC, anon, authenticated and `service_role`; a direct call is refused 42501.
- **Row shapes.** Refused: one UPDATE setting both a protected permission and `grant`; an inactive protected grant; a future-dated protected grant. Allowed: edits and re-points of a protected deny; ordinary re-points; grant-to-deny; `service_role` ordinary grants and deletes. `service_role` protected grants are refused.
- **Migration pre-check.** It passes on an empty table and on protected denies plus unrelated grants, and raises on any protected positive grant, including an inactive one.
- **CAP-1.** SUB-3's second row reproduced CAP-1's consequence: `app.tenant_capabilities()` returned 44 rows with `documents` both false and true while `plan_allows` returned true. The repair closes the only tenant path to that state. The CAP-1 row is not edited; SUB-3's row records this.
- **Event parity.** `service_role` holds no INSERT or UPDATE on `subscriptions`, so after the repair every writer is an event-emitting definer function. Direct-write event parity has no door.

Approval authorizes local implementation, proof, Review readiness and candidate publication through the pre-deploy readiness gate. It does not authorize a Primary write, which needs separate exact-byte authorization.

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

- **EARN IT.** SUB-3 is reproduced at `aal2` on a clean reset, against an authority stated in canon 28, canon 31 and SPEC-157's own rationale. Its consequence is a tenant granting itself a paid lifetime Enterprise plan and approving its own renewal; that is platform revenue and the platform's approval authority. No existing control owns it.
- **WORTH IT.** The consequence strikes the business model (ADR-0016: platform-mediated, bank-transfer billing with Platform Owner approval), and it reaches every tenant from the first. The repair is one table-local trigger, it closes both halves (subscription state and proof decision) at the single door that opened them, and it reinstates an owner-ratified mechanism rather than inventing a policy. Repairing now costs nothing to existing data (0 tenants).
- **Rejected alternatives:**
  - revoking `authenticated` INSERT/UPDATE on `subscriptions`: it leaves the grant live and explained, does not reach proof review or the approval arm, and breaks `42_...`;
  - a second rule in `app.has_permission`: a second authority inside the single decision point;
  - a `permissions.is_platform_reserved` column: a new concept with one data-driven reader, for two keys canon already names;
  - deriving "platform-only" as "held by no role": it would also forbid `ACCESS_API_*` and `VIEW_ADVANCED_DASHBOARDS`, which are unclassified tenant capabilities, not platform authority.
- **Observed, not part of this contract:** `app.derive_proof_reviewer` stamps `reviewed_by` with the uploader on INSERT, so a pending proof names a reviewer. It belongs to `subscription_payment_proofs` and SPP-3's reviewer-identity question, and was not classified here.
- **Untouched:** USR-3, CAP-1, BRANCH-1, BRANCH-2, STEPUP-1 and every other open finding. The registered worktree `owt/p2` is untouched.
