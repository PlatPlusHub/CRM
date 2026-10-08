# Change Request — SPEC-247

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Foundation Completion Programme Batch 6 Slice 34: give `public.tenant_license_activations` a truthful disposition and close **LIC-4** and **LIC-5**.

The surface is canon 09's activation code (SPEC-158): the Platform Owner issues a single-use code carrying plan, period and auto-renew, and the tenant admin redeems it, which runs the platform activation path. No signed-in role holds any privilege on the table; its three writers are the definer functions `app.platform_issue_license_token`, `app.platform_revoke_license_tokens` and `app.redeem_license_token`.

After this change two invariants hold:
- **An activation code carries the Platform Owner's current decision.** Suspending or cancelling a tenant revokes its outstanding code, so a tenant cannot undo either decision with a code issued before it. A code issued afterwards still restores the tenant.
- **A tenant has at most one live code**, under concurrency as well as in sequence.

Record the surface `AUDITED` and set the next capability to the Slice-35 target the selector then measures. Record **SUB-4**, a pre-existing check-then-act in `app.platform_transition_subscription` that the concurrency attacks exposed, as OPEN for the `subscriptions` slice, and do not repair it.

This contract does not touch LIC-1's accepted residual, the subscription state machine, plans, billing, payment proofs, n8n or any Phase-8 work.

## Business Reason

### Selection
`scripts/batch6_select_target.ps1` at `bdf6f1b` ranks `tenant_license_activations` first: `NOT-RECORDED`, Exposure 8, coverage 30, 5 test files, no direct write, 1 SECURITY DEFINER function, 3 RPCs and 1 concurrency signal. The runner-up is `service_requests` at 8/34.

### Authority
- **Canon 09:** the Platform Owner receives renewal proof, a time-sensitive activation code is generated, the Platform Owner hands it to the tenant admin, and the tenant admin enters it to activate renewal.
- **Canon 26** (`app.subscription_transition_allowed`): `suspended -> active` is "Platform owner restores subscription"; `cancelled -> active` and `expired -> active` are "Manual reactivation by platform owner"; `read_only -> active` and `grace_period -> active` are renewal.
- **Canon 00:** a suspended tenant stays read-only "until subscription access is restored".
- **SPEC-158's own design:** the Platform Owner fixes the terms at issuance and redemption can only apply them; rotation is revoke-then-issue, "so two live tokens cannot exist"; compromise recovery is revocation.
- **LIC-2 (`202607058400`):** single-use is a compare-and-swap on `consumed_at`; the function is the complete enforcement layer because the table has no signed-in door.
- **LIC-1:** a refused redemption is not audited; RESOLVED 2026-09-04 as an accepted residual. Not reopened: no new evidence touches it.

### LIC-4 (Medium, latent) — a tenant undid its own suspension or cancellation
Neither `app.platform_transition_subscription` nor anything else revokes a tenant's outstanding code when the Platform Owner suspends or cancels it, and `app.redeem_license_token` reaches `active` from any state canon 26 allows. Measured at `bdf6f1b` on the local stack, with committed fixtures and the tenant `owner` at aal2:
- **Suspension:** a code for `enterprise`/`annual` was issued while the tenant was `read_only`; the Platform Owner then suspended it (`read_only -> suspended`); the owner redeemed the old code. It committed: `suspended -> active`, now on `enterprise`, with a `license_token_redeemed` event.
- **Cancellation:** a code for `starter`/`monthly` was issued while `active`; the Platform Owner cancelled the tenant; the owner redeemed the old code. It committed: `cancelled -> active`.
- **Over HTTP:** on the unrepaired schema, `rpc/redeem_license_token` with a code issued before cancellation returned **204**, and the tenant was `active` afterwards.

A code captures the Platform Owner's consent at issuance. Canon gives restoring a suspended or cancelled tenant to the Platform Owner, so a code issued before that decision is not that consent. **Latent:** Primary holds 0 tenants and 0 codes.

### LIC-5 (Low, latent) — two live codes for one tenant
Issuance revokes the tenant's outstanding code and then inserts the new one. Two sessions issuing for one tenant, each holding its transaction for 3 seconds, both saw nothing to revoke and both committed: **2 live codes**, and the owner redeemed both, the second re-activating the tenant on its own terms. SPEC-158's "two live tokens cannot exist" was true in sequence and false concurrently. **Low:** issuance is `service_role` only and both plaintexts reach only the Platform Owner, so no tenant obtains a code the Platform Owner did not issue.

### The repair
One migration, two statements:
```sql
create unique index tenant_license_activations_one_live_per_tenant
    on public.tenant_license_activations (tenant_id)
    where consumed_at is null and revoked_at is null;
```
and `app.platform_transition_subscription` gains, after its canon-26 check and before it writes the subscription:
```sql
if p_new_state in ('suspended', 'cancelled') then
    perform app.platform_revoke_license_tokens(
        p_tenant_id, 'subscription ' || p_new_state || ' by platform owner');
end if;
```
- Revocation reuses `app.platform_revoke_license_tokens`, its one home, so it is audited (`license_token_revoked`, with count and reason) and nothing new is invented.
- Codes are revoked before the subscription row is written: the order in which redemption takes its locks (code, then subscription), so the two cannot deadlock.
- `grace_period`, `read_only` and `expired` keep their codes: renewing from them is what the code is for. A code issued after a suspension or cancellation is the Platform Owner's new decision and still restores.
- The index makes "one live code" the schema's rule. The second of two concurrent issuances waits for the first and is refused with 23505; sequential rotation is unchanged because issuance revokes before it inserts. An expired, unrevoked code still counts as live, and the next issuance revokes it, as today.
- The function keeps its signature, owner, `search_path`, SECURITY DEFINER, ACL (`postgres`, `service_role`) and comment; its text differs only by the inserted block.

### Rejected
- **Refusing redemption from `suspended` or `cancelled`:** it would also refuse a code the Platform Owner issues after the decision in order to restore the tenant, which canon allows.
- **Comparing `issued_at` with the time the tenant entered its state:** no column records that time, and reading it from events would make redemption depend on the event log.
- **A trigger on `subscriptions`:** `app.platform_transition_subscription` is the only writer that reaches `suspended` or `cancelled`. The platform's raw DML is PAR-5's question.
- **An advisory lock or `for update` on the tenant in issuance:** the index states the rule declaratively and also binds any other writer.
- **A uniform message for the revoke-versus-redeem race:** see Held.

### Held, recorded so a later slice does not rediscover it
- **The door:** `authenticated` and `anon` hold no privilege on the table and its policy is `platform_only`; no non-internal trigger.
- **Who redeems:** an aal1 owner is refused (`multi-factor authentication required for this role`); an employee is refused (`permission denied: MANAGE_TENANT_SETTINGS`); a rival tenant's owner holding a live code gets the generic `activation code is not valid`, because the lookup is scoped to the caller's tenant.
- **Which codes redeem:** revoked, expired, already-consumed (replay) and unknown codes are all refused with the one generic message.
- **No partial effect:** a code whose plan was retired after issuance is refused inside activation, and the whole redemption rolls back; the code stays live and the subscription unchanged.
- **LIC-2:** the compare-and-swap holds. The plaintext is never stored: only its SHA-256, and it is absent from every event payload.
- **Revoke racing redeem:** when a revocation commits between the redeemer's read and its claim, the existing CHECK `not_both_consumed_and_revoked` refuses the claim (23514), so the code stays revoked and nothing activates. The message names the constraint rather than the generic one, but only a holder of the real code mid-race can see it, and it reveals only that the code was just revoked. Not a finding.
- **Suspend racing redeem:** suspension first means the redemption is refused (as above). Redemption first means the suspension waits on the row lock and then lands, so the Platform Owner's later decision wins. Neither order deadlocks.
- **Plan and period** are validated at issuance and again at activation.

### SUB-4 (Low), recorded and not repaired here
`app.platform_transition_subscription` reads the subscription's state without a lock, judges canon 26 on it, and then writes. Measured at `bdf6f1b` with two live sessions: a redemption committed `read_only -> active` while a suspension waited for the row; the suspension, judged as `read_only -> suspended`, then wrote `suspended` over the `active` row. Canon 26 has no `active -> suspended`, and the events read `subscription_activated read_only -> active` then `subscription_suspended read_only -> suspended`. `app.platform_activate_subscription` reads the same way. Both are the `subscriptions` surface's check-then-act, reached only by the Platform Owner, with an outcome (suspended) that matches the Platform Owner's intent. Repairing it is that slice's work; it is recorded OPEN, Low.

## Risks

- **A legitimate code lost.** A Platform Owner who suspends or cancels a tenant and later wants the old code honoured must issue a new one. This is the intended consequence: restoring is the Platform Owner's act.
- **A refused issuance.** The second of two concurrent issuances for one tenant now fails with 23505 instead of leaving two live codes; the Platform Owner issues again, and that issue supersedes. Primary holds 0 codes, so the index builds on an empty table.
- **Pinned consumers.** Test 42 suspends a tenant that holds no code; Tests 43 and 80 rotate in sequence; Test 133 and the HTTP suites count no revocations. On the prototype every existing test file passed unchanged.
- **Primary deployment** adds one index and replaces one function body, and nothing else. It requires separate exact-byte owner authorization (Gate 2); approving this contract does not authorize it.
- **Workstation, not in scope:** resets for this contract run from the main checkout, because a reset from a scratch git worktree leaves local storage without `bucketid_objname` (recorded in SPEC-246).

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-247-an-activation-code-carries-the-platforms-current-decision.md`
- `supabase/migrations/20261008170000_an_activation_code_carries_the_platforms_current_decision.sql`
- `supabase/tests/147_an_activation_code_carries_the_platforms_current_decision_test.sql`
- `scripts/verify_journey_branches.ps1`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607054000_subscription_lifecycle_and_platform_authority.sql`
- `supabase/migrations/202607054100_tenant_license_activation.sql`
- `supabase/migrations/202607058400_a_single_use_code_is_single_use_under_concurrency_too.sql`
- `supabase/tests/35_subscription_write_gate_test.sql`
- `supabase/tests/42_subscription_lifecycle_test.sql`
- `supabase/tests/43_license_activation_test.sql`
- `supabase/tests/53_api_surface_test.sql`
- `supabase/tests/80_subscription_licensing_test.sql`
- `supabase/tests/83_actor_attribution_test.sql`
- `supabase/tests/131_platform_authority_cannot_be_granted_test.sql`
- `supabase/tests/133_security_event_log_authority_test.sql`
- `reports/architecture-decision-records.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/09_saas_plans_and_access.md`
- `_ORVION_CANONICAL/26_state_machines.md`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `scripts/verify_database.sql`
- `scripts/verify_api_end_to_end.ps1`
- `scripts/verify_care_journeys.ps1`
- `scripts/verify_lifecycle_branches.ps1`
- `scripts/verify_role_journeys.ps1`
- `scripts/verify_storage_end_to_end.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/09_saas_plans_and_access.md` (activation code); `_ORVION_CANONICAL/26_state_machines.md` (subscription transitions); `_ORVION_CANONICAL/28_permissions_matrix.md` (MANAGE_TENANT_SETTINGS, terminal states)
- `reports/master/MASTER_GAP_REGISTER.md` (LIC-1, LIC-2, LIC-3, SUB-1 to SUB-3, PAR-5, STEPUP-1)
- `reports/master/MASTER_EXECUTION_PLAN.md` Batch 6 method and EC-1…EC-11; `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `supabase/migrations/202607054100_tenant_license_activation.sql`; `supabase/migrations/202607058400_a_single_use_code_is_single_use_under_concurrency_too.sql`
- Current local `app.platform_issue_license_token`, `app.platform_revoke_license_tokens`, `app.redeem_license_token`, `app.platform_activate_subscription`, `app.platform_transition_subscription`, `app.subscription_transition_allowed`
- Tests 35, 42, 43, 80, 133

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- supabase-primary
- github

## Additional Verification

- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A partial unique index: one live code per tenant | `app.platform_issue_license_token` (rotation); Tests 43 and 80 (sequential issue, rotation, redemption); `verify_journey_branches.ps1` and `verify_role_journeys.ps1` (issuance) | WRITE | The prototype was a scratch worktree at `bdf6f1b`; the migration was applied with its ledger row on a stack reset from the main checkout. Migration SHA-256 `42fbb882ea584917c2740369a55c565a62a3e9d1b5f74d972f3797b05b532668`, md5 `b1ac5e31a7627221b3bde8bd8ac4ed26`, 4393 bytes. Tests 43 and 80 pass unchanged: issuance revokes before it inserts, so rotation never meets the index. Two concurrent issuances: the first commits, the second is refused 23505 naming `tenant_license_activations_one_live_per_tenant`, and 1 code is live. |
| `app.platform_transition_subscription` revokes outstanding codes on `suspended` and `cancelled` | Test 42 (suspension with no code); Test 131 (its ACL); Test 133 (security-event producers); the redemption path | WRITE | Its text differs from `bdf6f1b`'s only by the inserted six-line block; signature, owner, SECURITY DEFINER, empty `search_path`, ACL `{postgres=X, service_role=X}` and comment are unchanged. Tests 42, 131 and 133 pass unchanged. Probes on the prototype: suspension and cancellation each revoke the outstanding code with one `license_token_revoked` event, the old code is refused with the generic message, the tenant stays suspended or cancelled, a fresh code then restores it, and another tenant's code is untouched. Suspension racing redemption resolves in both orders without deadlock (Business Reason, Held). |
| Test 147 and two HTTP checks | `supabase/tests`; `verify_journey_branches.ps1` | WRITE | Test 147 (SHA-256 `2d244589d7fdf2a5393131c872628004c404094439646b01617c8cc86de8d65a`, `plan(15)`) passes 15/15 on the prototype. On the unrepaired schema, assertions 5–8 and 12–14 fail, each for its intended reason. `verify_journey_branches.ps1` (SHA-256 `4d321256f8508fa9435031c73a4c05821150dcfbf537dffe008a47db9bc94a2d`) gains two LIC-4 checks after the API-3 licensing block and restores the tenant to `active` afterwards: 85/0 on the prototype. On the unrepaired schema exactly those two fail (the old code redeemed with 204; the tenant `active`) and the other 83 pass. |
| The generated API contract | `MASTER_API_CONTRACT.md` | WRITE | The canonical generator against the prototype reports 80 RPC endpoints (80 with HTTP evidence), 8 views and 74 tables, byte-identical to the committed contract (SHA-256 `d28fb5672ca9c0795a99a74746069c973e1392edcc5e3d2a5a315348138175fd`): no grant, table or client RPC moves. Step 7 regenerates it, and it stays unchanged. |
| Suite, HTTP and smoke | full pgTAP; the six HTTP suites; `scripts/verify_database.sql` | VERIFY | On the prototype, in `-Finish`'s order on a main-checkout reset: Test 147 15/15; pgTAP Pass A 147 files / 2689 assertions PASS (2674 + 15); HTTP 35 + 40 + 85 + 122 + 122 + 60 = 464 passed, 0 failed; Pass B 147 / 2689 PASS; smoke `ALL CHECKS PASSED (78 tables, … 71/622 catalog, …)`; the plan sum 147 / 2689; `git diff --check` clean. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | Measured on the local prototype against the recorded Primary values (243 migrations, `f50dea30…`/3108): functions `f704b7836a75f3f623a4112a28e5a779`/320 → `127430f783d23b2b89e474636be684c9`/320; indexes `56872e87068cc220c988957980511eae`/299 → `22a4d58cef10893d1279b6ddd9ff38f0`/300; combined → `bb42b1b7a8ee985d892ccaf4426ce4ce`/3109. Triggers, policies, constraints, grants, columns, views, status transitions and RLS are unchanged. The 244-file ledger fingerprint is `9e846936c3b320e03eaf125844f46223`. |
| Measured state that moves | manifest (`Live state`, suite and HTTP figures, coverage, Last Completed, Current Module, Next capability); `primary-ledger-evidence.json`; `ai-map.json` | WRITE | 243 → 244 migrations, latest `20261008170000`; 146 → 147 files, 2674 → 2689 assertions; HTTP 462 → 464; coverage 34 → 35 of 78. Tables (78), catalog (71/622) and client RPCs (80) do not move. Primary values are written only from fresh post-deploy readings. |
| LIC-4 and LIC-5 fixed, SUB-4 recorded; the surface `AUDITED` | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24, 25 | WRITE | Test 147's `-- ATTACK-CLASSES:` line and negative assertions satisfy Check 24 for `tenant_license_activations`. SUB-4's owner field is an engineering scheduling position, so Check 25 does not read it as an owner decision. The disposition row names this contract as its session. |
| CI-only guard self-tests and repository consistency | `scripts/test_*_guard.ps1` (four); `scripts/check_repository_consistency.ps1` | VERIFY | On the prototype, future-date (18/0) and status-contradiction (33/0) pass. Primary-ledger (11 passed, 2 failed) and cold-start (25 passed, 9 failed) fail ONLY their CONTROL cases that require an untouched copy of the repository to be CLEAN; every mutation case passes. Repository consistency reports exactly the pre-deploy measured-state drift: `manifest says 243 migrations, repository holds 244`; latest `20261008150000` vs `20261008170000`; ledger fingerprint `201d938a…` vs `9e846936…`; `146 test files` vs 147; `2674 assertions` vs 2689; RECOVER-1 ledger evidence. These are not waived: Step 7 makes them true and Step 8 requires them green. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused tests, pgTAP A/B, the six HTTP suites, smoke and mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| LIC-4, LIC-5, SUB-4 and the disposition describe the local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |
| The four CI-only guard self-tests pass | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `app.platform_revoke_license_tokens`, SPEC-158's one home for revoking a tenant's outstanding codes and auditing it, now also called by the Platform Owner's suspension and cancellation; and a partial unique index, the declarative form of the rule SPEC-158 already states for issuance. Nothing else is added: no table, column, trigger, permission, policy, grant, event type or catalog value. Rejected: refusing redemption by state; comparing `issued_at` with a state-entry time; a trigger on `subscriptions`; a lock in issuance.

Added Property: A code issued before the Platform Owner suspends or cancels a tenant can no longer be redeemed, so only the Platform Owner restores a suspended or cancelled tenant, as canon 26 says; and a tenant never holds two live codes, under concurrency as well as in sequence.

Causal Negative: The pre-repair measurements in Business Reason, at `bdf6f1b`:
- a code issued while `read_only`, redeemed after suspension: `suspended -> active` on the code's plan;
- a code issued while `active`, redeemed after cancellation: `cancelled -> active`;
- the same over HTTP: `rpc/redeem_license_token` returned 204 and the tenant was `active`;
- two concurrent issuances: 2 live codes, both redeemed;
- Test 147 on the unrepaired schema: assertions 5–8 and 12–14 fail, each for its intended reason (the code still live, no revocation event, no exception where 42501 was required, the tenant `active`, or the second live row accepted).

Positive Test Design: Tenant A starts `read_only` with an `owner` who redeems at aal2; tenant B holds a live code and nothing else. Positive controls: a live code renews `read_only -> active`; issuing after a consumed code succeeds; `grace_period` and `read_only` keep the outstanding code; a code issued after the suspension restores `suspended -> active`; sequential rotation leaves the newest code as the one live code.

Negative Test Design:
- **Suspension:** revokes the outstanding code, audited once with its reason and count; the old code is refused 42501 `activation code is not valid`; the tenant stays `suspended`; tenant B's code stays live.
- **Cancellation:** the old code is refused 42501 with the generic message, and the tenant stays `cancelled`.
- **One live code:** with one live code present, a second live row for the tenant is refused 23505 at the statement.
- **Over HTTP:** a code issued before the Platform Owner cancelled the tenant is refused with the generic message, and the tenant stays `cancelled`.

Non-Empty Population Obligation: Two tenants. Tenant A has a `starter` subscription in `read_only`, an `owner` user with its role, and codes issued across the test; tenant B has an `active` subscription and one live code.

Mutation Obligation: Out of file, record a surface: the md5 of `app.platform_transition_subscription`'s text and of the new index's definition (or its absence). For each mutant:
1. Install it and prove the surface differs.
2. Run Test 147 and record the failing assertions.
3. Restore it and prove the surface equals the base.

A mutant whose installation is not proven is a harness error, never a kill.

| Mutant | Change | Expected to fail |
| --- | --- | --- |
| M1 | the one-live index dropped | 14 |
| M2 | the transition revokes nothing | 5, 6, 7, 8, 12, 13 |
| M3 | only suspension revokes | 12, 13 |
| M4 | the index ignores consumption (`where revoked_at is null`) | 3, 4, 6, then the file aborts at the next issuance |
| M5 | every transition revokes | 4, 6 |
| H1 | the transition revokes nothing, over HTTP | `verify_journey_branches.ps1`'s two LIC-4 checks |

Prototype result: base surface ``5de22847f871687907f159f6656a727c 365e782ab9b05ce724cf3a26140e3356` (function text md5, index definition md5)`. Every installation changed the surface and every restoration returned it to the base. All five were killed, exactly as expected: M1 [14]; M2 [5, 6, 7, 8, 12, 13]; M3 [12, 13]; M4 [3, 4, 6] and the file aborted with 23505 at assertion 10's fixture issuance; M5 [4, 6]. H1, on a fresh main-checkout reset with the migration applied, failed exactly the two LIC-4 checks (the old code redeemed with 204; the tenant `active`) and passed the other 83; installation and restoration of the function text proven.

Post-Implementation Proof Obligation: All of the following, on the final bytes and through canonical `-Finish`:
- the focused test, a clean reset from the main checkout, pgTAP Pass A, the declared HTTP suite, pgTAP Pass B and smoke;
- the out-of-file mutations M1–M5, H1 and the pre-repair causal negative;
- the generated artifacts, the four CI-only guard self-tests, repository consistency and `git diff --check`;
- fresh Primary evidence, parity evidence and the Primary ledger check.

## Implementation Steps

1. **Check** that `supabase/migrations/20261008170000_an_activation_code_carries_the_platforms_current_decision.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `42fbb882ea584917c2740369a55c565a62a3e9d1b5f74d972f3797b05b532668`, md5 `b1ac5e31a7627221b3bde8bd8ac4ed26`, 4393 bytes.
   - Its statements are the partial unique index `tenant_license_activations_one_live_per_tenant` and `create or replace function app.platform_transition_subscription(...)` with the revocation block, preceded by a comment block stating the authority and LIC-4's and LIC-5's measurements.
   - If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/147_an_activation_code_carries_the_platforms_current_decision_test.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `2d244589d7fdf2a5393131c872628004c404094439646b01617c8cc86de8d65a`, `select plan(15);`.
   - Its `-- ATTACK-CLASSES:` line reads `BUSINESS STATE TENANT OBSERVABILITY CONCURRENCY DOOR=N/A PRIVILEGE=N/A AUTH=N/A INPUT=N/A REPLAY=N/A`, with each `N/A` reason in its header.
   - Then edit `scripts/verify_journey_branches.ps1`, LF, byte-identical to the prototype: two LIC-4 checks after the API-3 licensing block's employee check, followed by restoring the tenant to `active`; SHA-256 `4d321256f8508fa9435031c73a4c05821150dcfbf537dffe008a47db9bc94a2d`.
   - If a target carries content other than its `bdf6f1b` bytes or its frozen value, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` already contains a `LIC-4` row. If not, make these edits and nothing else:
   - **Register:**
     - a 2026-10-08 Slice-34 freshness entry, with the previous one demoted to `Previously:`;
     - new rows LIC-4 (Medium) and LIC-5 (Low), FIXED by SPEC-247 locally with Primary pending and Cert `🛡`, with the measurements above;
     - a new row SUB-4 (Low, OPEN), with the evidence above, its owner field an engineering scheduling position for the `subscriptions` slice.
   - **Disposition:**
     - a freshness entry, with the previous one demoted;
     - coverage 35 of 78 (14 `AUDITED`, 18 `AUDITED-OPEN`, 3 `PARTIAL`, 43 `NOT-RECORDED`) and the "All 35" line;
     - the `tenant_license_activations` row `AUDITED` / `ADVERSARIAL` / SPEC-247 / LIC-4, LIC-5, with its evidence and its swept non-defects.

   If a target carries content other than its `bdf6f1b` bytes, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 values:
   - a clean local reset from the main checkout; Test 147 and the focused Tests 42, 43 and 80;
   - pgTAP Pass A, all six HTTP suites, then pgTAP Pass B without reset; smoke and the plan sum;
   - the mutation evidence M1–M5 and H1, and the causal negative;
   - the API-contract and map generators;
   - the scope check, `git diff --check` and repository consistency.

   Treat as expected at this boundary only: an undeployed Primary, the pre-deploy repository-consistency drift listed in Consumer Closure, and the guard self-test CONTROL failures it causes.

   Read a fresh Primary baseline, read-only:
   - the project URL, the full ordered ledger and the absence of the target migration;
   - the function and structural surfaces;
   - `tenant_license_activations`' ACL and indexes; `app.platform_transition_subscription`'s text md5, security mode and ACL;
   - the tenant, subscription, activation-code and security-event counts.

   Record the predicted delta.
5. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 4 and present the Gate-2 package. Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261008170000_an_activation_code_carries_the_platforms_current_decision`. If it is absent and deployment is separately authorized:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts, the table's indexes and the function's md5.
   - On an exact match, prove the transmitted text's md5 server-side, then apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row, its stored statement md5 equal to the file's, and no existing target version.
   - Read fresh: the ledger, the function surface and all ten structural surfaces; the table's ACL and indexes; the function's definition, security mode and ACL; the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with 464 HTTP assertions last passed on the Step-4 date.
   - Confirm that `supabase/tests` holds 147 files whose literal `plan(N)` values sum to 2689, then set `Suite **147 files / 2689 assertions**`; if either differs, stop.
   - Set Batch 6 coverage to 35 of 78, all thirty-five at `ADVERSARIAL`.
   - Mark LIC-4 and LIC-5 `DEPLOYED` with Cert `✅`, worded without a date beneath the register's freshness line.
   - Regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` (stored LF) with the canonical generators.
   - Run the four `scripts/test_*_guard.ps1` and require each to pass.
   - Set the Runtime Checkpoint to DONE.
   - Run `check_primary_ledger.ps1`, `check_database_parity_evidence.ps1`, repository consistency and `git diff --check`.

   If Primary is unproven, stop.
8. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, do all of the following in the Complete commit:
     - transition to Complete and clear `Active Change Request`;
     - run `scripts/batch6_select_target.ps1` and record its Top-12;
     - set `Last Completed` to SPEC-247 / Slice 34;
     - set `Current Module` to Foundation Completion Programme Batch 6 resuming at Slice 35;
     - set `Next capability` to **Foundation Completion Programme — Batch 6 Slice 35**, naming the measured first target, followed by the Phase-8 order roadmap 32 owns, keeping its closed-chapter and standing-fact sentences;
     - keep the manifest within 7000 characters;
     - regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate with `scripts/publish_candidate.ps1` and require exact-SHA candidate CI.
   - Promote the same accepted SHA, require main CI, and run `-Certify` for `REMOTE_CERTIFY: READY`.
   - Verify synchronized clean refs.

## Acceptance Criteria

- [ ] Suspending or cancelling a tenant through `app.platform_transition_subscription` revokes its outstanding code, audited as one `license_token_revoked` event naming the transition; a code issued before either decision is refused with the generic 42501 message, in pgTAP and over HTTP, and the tenant stays suspended or cancelled.
- [ ] `grace_period` and `read_only` keep the outstanding code; a code issued after a suspension still restores the tenant; another tenant's code is untouched.
- [ ] A tenant cannot hold two live codes: a second live row is refused 23505 at the statement, the second of two concurrent issuances is refused, and sequential rotation and issuance after a consumed code are unchanged.
- [ ] `app.platform_transition_subscription` differs from `bdf6f1b` only by the revocation block, with signature, owner, security mode, `search_path`, ACL and comment unchanged; `app.redeem_license_token`, `app.platform_issue_license_token`, `app.platform_revoke_license_tokens` and `app.platform_activate_subscription` are byte-identical.
- [ ] The held controls stay held: no signed-in privilege on the table; aal1, employee and rival-tenant redemption refused; revoked, expired, replayed and unknown codes refused with the one generic message; a failed activation consumes nothing.
- [ ] Mutants M1–M5 are each killed against Test 147, and H1 against `verify_journey_branches.ps1`'s two LIC-4 checks, with installation and restoration proven. The causal negative is recorded.
- [ ] LIC-4 and LIC-5 are fixed and deployed in the register. SUB-4 is recorded OPEN, Low, and unrepaired. LIC-1, LIC-2 and LIC-3 are unchanged.
- [ ] `tenant_license_activations` is `AUDITED` / `ADVERSARIAL` in the disposition record, and coverage is 35 of 78. No other surface's row changed.
- [ ] The migration, Test 147 and the HTTP script matched their frozen SHA-256 values when applied.
- [ ] Primary, the recorded evidence, the manifest (244 migrations; 147 files / 2689 assertions; 464 HTTP assertions), the API contract and `ai-map.json` agree, and the four CI-only guard self-tests and repository consistency pass.
- [ ] The manifest names Batch 6 Slice 35 and its measured target as the next capability, with no Active Change Request.
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-10-08 — Owner-delegated approval and execution start

The owner's Slice-34 directive of 2026-10-08 directed this bounded Batch-6 slice to proceed through repository governance. It covers reproducing the findings, repairing only evidence-backed defects with the smallest correction, giving the surface a truthful disposition, stopping once at the exact Primary Gate-2 boundary if a migration is earned, then publishing and synchronizing. It does not authorize any Primary write; Gate 2 is required.

- Draft `400f9e9`; a read-only evaluation of it returned `APPROVAL_EVIDENCE: PASS` (profiles DATABASE and REPOSITORY).
- Approved at `be70746`; its pre-commit Gate reported `APPROVAL_EVIDENCE: PASS`.
- In Progress from this commit. Resume Step 1. Primary stays read-only until Gate 2; Secondary `brplkqmbzffpxqgkkdzo` is never contacted.

### 2026-10-08 — Steps 1-3 applied (uncommitted until after deployment)

- **Step 1:** the migration was absent and was created byte-identical to the prototype: SHA-256 `42fbb882ea584917c2740369a55c565a62a3e9d1b5f74d972f3797b05b532668`, md5 `b1ac5e31a7627221b3bde8bd8ac4ed26`, 4393 bytes, 88 LF lines, ASCII.
- **Step 2:** Test 147 was absent and was created byte-identical (SHA-256 `2d244589d7fdf2a5393131c872628004c404094439646b01617c8cc86de8d65a`, `plan(15)`). `scripts/verify_journey_branches.ps1` carried its `bdf6f1b` bytes and now hashes to the frozen `4d321256f8508fa9435031c73a4c05821150dcfbf537dffe008a47db9bc94a2d`.
- **Step 3:** the register had no `LIC-4` row and both reports carried their `bdf6f1b` bytes. The register gained the Slice-34 freshness entry (the Slice-33 one demoted), the rows LIC-4 and LIC-5 (FIXED locally, Primary pending, Cert `🛡`) and SUB-4 (Low, OPEN, owner field `engineering: …`). The disposition record gained its freshness entry, coverage 35 of 78 (14 `AUDITED`, 18 `AUDITED-OPEN`, 3 `PARTIAL`, 43 `NOT-RECORDED`), the "All 35" line and the `tenant_license_activations` row `AUDITED` / `ADVERSARIAL` / SPEC-247 / LIC-4, LIC-5.

### 2026-10-08 — Pre-deploy readiness gate

Run on HEAD `7026c7a` with Steps 1–3 in the working tree, every reset from the main checkout:
- **Reset:** exit 0; storage 68 migrations; ledger 244, latest `20261008170000`.
- **Focused:** Test 147 15/15; Test 42 28/28; Test 43 19/19; Test 80 19/19.
- **pgTAP Pass A:** 147 files / 2689 assertions, PASS.
- **HTTP:** `verify_api_end_to_end` 35/0, `verify_care_journeys` 40/0, `verify_journey_branches` 85/0, `verify_lifecycle_branches` 122/0, `verify_role_journeys` 122/0, `verify_storage_end_to_end` 60/0: 464 passed, 0 failed.
- **pgTAP Pass B** (no reset): 147 / 2689, PASS. **Smoke:** `ALL CHECKS PASSED (78 tables, … 71/622 catalog, …)`. **Plan sum:** 147 files, 2689.
- **Local surfaces:** functions `127430f783d23b2b89e474636be684c9`/320; indexes `22a4d58cef10893d1279b6ddd9ff38f0`/300; every other surface equal to Primary's; combined `bb42b1b7a8ee985d892ccaf4426ce4ce`/3109; ledger fingerprint 244/`9e846936c3b320e03eaf125844f46223`. `app.platform_transition_subscription` text md5 `5de22847…`, SECURITY DEFINER, `search_path=""`, ACL `{postgres=X, service_role=X}`; the other four licensing functions unchanged.
- **Mutation** on these bytes, base surface `5de22847… 365e782a…`, every installation and restoration proven: causal negative (index dropped and no revocation) [5, 6, 7, 8, 12, 13, 14]; M1 [14]; M2 [5, 6, 7, 8, 12, 13]; M3 [12, 13]; M4 [3, 4, 6], then 23505 at the next issuance; M5 [4, 6]. All killed, as frozen. H1 on a fresh reset: `verify_journey_branches.ps1` 83 passed and failed exactly the two LIC-4 checks (the old code redeemed with 204; the tenant `active`); restoration proven, then a final reset to the repository state.
- **Generators:** the API contract regenerates byte-identical (`d28fb567…`); `ai-map.json` changed only its timestamp and was left at its committed bytes for Step 7.
- **Guards:** future-date 18/0 and status-contradiction 33/0 pass; cold-start 25/9 and primary-ledger 11/2 fail only their CONTROL cases, as predicted.
- **Repository consistency:** exactly the predicted pre-deploy drift (243 vs 244 migrations; latest; fingerprint `201d938a…` vs `9e846936…`; 146 vs 147 files; 2674 vs 2689 assertions; RECOVER-1).
- **Scope:** the working tree changes only Write Scope paths; `git diff --check` clean.

**Fresh Primary baseline, read-only** (`https://vrvtsxexkiiiivlkdxzp.supabase.co`):
- **Ledger:** 243, fingerprint `201d938a80ae5fe6d32fb8ef6f3a7619`, latest `20261008150000`; the target absent by version and name.
- **Surfaces:** functions `f704b7836a75f3f623a4112a28e5a779`/320, triggers `d07aa82d…`/306, policies `b67d466a…`/125, constraints `cea733ef…`/525, grants `6727f6d8…`/189, columns `448db887…`/1134, views `10bb212a…`/16, indexes `56872e87068cc220c988957980511eae`/299, status_transitions `db2165c7…`/115, rls_enabled `c117cbf7…`/79; combined `f50dea30bd2a7c4cf4c22ddd9e191622`/3108, equal to the recorded evidence.
- **The surface:** `tenant_license_activations` ACL `{postgres=arwdDxtm, service_role=arwdDxtm}`, indexes `pkey`, `tenant_idx`, `token_hash_key`; `app.platform_transition_subscription` ACL `{postgres=X, service_role=X}`.
- **Business rows:** 0 tenants, subscriptions, activation codes and security events.

**Predicted delta on Primary:** 244 migrations, fingerprint `9e846936c3b320e03eaf125844f46223`; functions `127430f783d23b2b89e474636be684c9`/320; indexes `22a4d58cef10893d1279b6ddd9ff38f0`/300; combined `bb42b1b7a8ee985d892ccaf4426ce4ce`/3109; every other surface unchanged; business counts unchanged.

Stopping at Gate 2 (Step 5): no owner authorization for the migration is recorded.


### 2026-10-08 — Human Gate 2: owner authorization

The owner authorized deployment to Primary `vrvtsxexkiiiivlkdxzp` of only `supabase/migrations/20261008170000_an_activation_code_carries_the_platforms_current_decision.sql`, SHA-256 `42fbb882ea584917c2740369a55c565a62a3e9d1b5f74d972f3797b05b532668`, md5 `b1ac5e31a7627221b3bde8bd8ac4ed26`, exclusively those bytes and the approved scope, with the guarded rename of a temporary connector version only if required.

**Stop conditions before writing,** any material difference voiding it: pre-deploy HEAD other than `08a0a3d`; the migration's hashes; Test 147 or the HTTP suite differing from their tested bytes; Primary not at 243 migrations with latest `20261008150000`; the target version present; schema or function definitions differing from the approved baseline; business data changed; the new index already present.

**Required behaviour:** suspension and cancellation revoke outstanding codes through the existing, audited revocation; a code issued afterwards still reactivates; one unconsumed, unrevoked code per tenant; authentication, MFA, tenant isolation, hashing, expiry, replay protection (LIC-2) and transition authority intact; a losing concurrent issuance leaves no unaudited or usable second code. No new role, table, trigger, policy or RPC. **SUB-4 stays OPEN** and is not implemented here; SPEC-247 is not evidence that concurrent subscription transitions are serialized. A newly reproducible LIC-4 bypass after deployment means stop, not complete. Secondary `brplkqmbzffpxqgkkdzo` stays out of bounds.

### 2026-10-08 — Step 6: Primary deployment

**Prewrite recheck, every condition exact:**
- refs: HEAD `08a0a3db0a644dfee7461c76e80c4e225fe7c159`; `origin/main` and `origin/orvion-preflight` `bdf6f1b`;
- the file: SHA-256 `42fbb882…`, md5 `b1ac5e31…`, 4393 bytes, 88 LF, 0 CR, 0 non-ASCII; Test 147 `2d244589…` and `verify_journey_branches.ps1` `4d321256…` unchanged;
- project URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`;
- ledger 243, `201d938a80ae5fe6d32fb8ef6f3a7619`, latest `20261008150000`; the target absent by version and name; `tenant_license_activations_one_live_per_tenant` absent;
- functions `f704b7836a75f3f623a4112a28e5a779`/320 and indexes `56872e87068cc220c988957980511eae`/299, equal to the recorded evidence; `app.platform_transition_subscription` SECURITY DEFINER, owner `postgres`, `search_path=""`, ACL `{postgres=X, service_role=X}`, raw text md5 `5ed79ca4…` as read before Step 4;
- 0 tenants, subscriptions, activation codes, security events and events.

**Write:**
- The text to transmit was first proven server-side, read-only, to hash to md5 `b1ac5e31a7627221b3bde8bd8ac4ed26`, 4393 bytes, 88 LF, no CR.
- That text was applied through `apply_migration` as `an_activation_code_carries_the_platforms_current_decision`. The connector assigned the temporary version `20261008173434`; its single stored statement has md5 `b1ac5e31…` and 4393 bytes, equal to the file.
- One guarded CTE UPDATE renamed only that row to `20261008170000`. The guard required 244 rows, the other 243 hashing to the baseline, the statement md5 to match and no existing target. All four held, and 1 row was renamed.

**Fresh postwrite reads, every value equal to the frozen prediction:**
- **Ledger:** 244, `9e846936c3b320e03eaf125844f46223`, latest `20261008170000`; exactly one row for the migration, under the target version; the temporary version is gone.
- **Surfaces:** functions `127430f783d23b2b89e474636be684c9`/320, triggers `d07aa82d…`/306, policies `b67d466a…`/125, constraints `cea733ef…`/525, grants `6727f6d8…`/189, columns `448db887…`/1134, views `10bb212a…`/16, indexes `22a4d58cef10893d1279b6ddd9ff38f0`/300, status_transitions `db2165c7…`/115, rls_enabled `c117cbf7…`/79; `_combined` `bb42b1b7a8ee985d892ccaf4426ce4ce`/3109.
- **The index:** `CREATE UNIQUE INDEX tenant_license_activations_one_live_per_tenant ON public.tenant_license_activations USING btree (tenant_id) WHERE ((consumed_at IS NULL) AND (revoked_at IS NULL))`; the table now carries 4 indexes and its ACL is unchanged.
- **The function:** `app.platform_transition_subscription` text md5 `5de22847f871687907f159f6656a727c`, byte-equal to the locally proven text; SECURITY DEFINER, owner `postgres`, `search_path=""`, ACL `{postgres=X, service_role=X}`, comment kept. `app.platform_issue_license_token`, `app.platform_revoke_license_tokens` and `app.redeem_license_token` read the same md5 as before the write.
- **Business rows:** 0 tenants, subscriptions, activation codes, security events and events.

**Behaviour on the deployed bytes,** proven locally on the byte-identical function and index, because no business data or fixture is written on Primary:
- Test 147 15/15 and `verify_journey_branches.ps1` 85/0 at Step 4; the causal negative, M1–M5 and H1 killed on these bytes.
- **Concurrent issuance:** two sessions; the first returned its plaintext, the second raised 23505 on `tenant_license_activations_one_live_per_tenant` and returned none. Afterwards 1 live code, exactly 1 added `license_token_issued` event and exactly 1 row for the winner's hash, and that code redeemed. The loser's transaction rolled back whole, so it left neither a usable code nor an audit row.
- **LIC-4:** after suspension the old code was refused with the generic message and the tenant stayed suspended; an aal1 owner (`multi-factor authentication required for this role`), an employee (`permission denied: MANAGE_TENANT_SETTINGS`) and a rival tenant's owner (generic) were refused; a fresh code restored the tenant. No bypass was found.
- **LIC-2:** replaying a consumed code is refused with the generic message.
- LIC-1 unchanged; SUB-4 OPEN and unrepaired.

No business-data write and no fixture was made on Primary. Secondary `brplkqmbzffpxqgkkdzo` was not contacted.

### 2026-10-08 — Step 7: evidence and measured state

- **Evidence:** `reports/evidence/primary-ledger-evidence.json` was rewritten from the fresh readings only: 244 migrations, `9e846936…`, functions `127430f7…`/320, structural `bb42b1b7…`/3109, head `08a0a3d`. Its ledger is the Primary ledger read with its own `read_query`; it equals the recorded 243 entries plus the new one, and the repository's 244 migration files.
- **Manifest:** `supabase/tests` holds 147 files whose `plan(N)` values sum to 2689. `Live state` reads 244 migrations, latest `20261008170000`, the same hashes and counts; 78 tables, `71/622` catalog, 80 client RPCs; `Suite **147 files / 2689 assertions**` and 464 HTTP assertions last passed 2026-10-08. Batch 6 coverage reads 35 of 78, all thirty-five at `ADVERSARIAL`. The manifest measures 6888 characters.
- **Register:** LIC-4 and LIC-5 are marked DEPLOYED with Cert `✅`. SUB-4 stays OPEN; LIC-1, LIC-2 and LIC-3 are unchanged.
- **Generators:** `MASTER_API_CONTRACT.md` regenerates unchanged (SHA-256 `d28fb5672ca9c0795a99a74746069c973e1392edcc5e3d2a5a315348138175fd`), and `ai-map.json` was regenerated and stored LF.
- **Checks:** the four CI-only guard self-tests pass (cold-start 34/0, future-date 18/0, primary-ledger 13/0, status-contradiction 33/0); `check_primary_ledger.ps1` `RECOVER-1 LEDGER EVIDENCE: CLEAN`; `check_database_parity_evidence.ps1` `PRIMARY PARITY EVIDENCE: CLEAN`; repository consistency `CLEAN`; `git diff --check` clean.
- **Checkpoint:** the Runtime Checkpoint is DONE, so Step 8's `-Finish` runs in VERIFY mode.

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

- **EARN IT.** LIC-4 was reproduced with committed fixtures for suspension and for cancellation, over HTTP, and by Test 147 failing for its intended reasons. LIC-5 was reproduced with two live sessions.
- **WORTH IT.** A tenant the Platform Owner suspended or cancelled could restore itself, on the plan an older code carried, which canon 26 gives only to the Platform Owner. A stated single-live-code rule held only in sequence.
- **SIMPLIFY IT WITHOUT WEAKENING.** One index and one call to the existing revocation function. No table, column, trigger, permission, policy, grant or event type is added, and the tenant-facing redemption function is untouched.
- **Owner authorization (2026-10-08).** The owner's Slice-34 directive authorizes reproducing, repairing only evidence-backed defects, recording the disposition, and stopping once at the exact Primary Gate 2. It does not authorize any Primary write.
- **Deliberately not changed:** LIC-1's accepted residual; SUB-4 and `app.platform_activate_subscription`; the constraint-named message in the revoke-versus-redeem race; the subscription state machine, plans, billing and payment proofs; canon 09, 26 and 28; the n8n workflow, PH8-10 and Phase 8; the registered worktrees `owt/p2` and `C:\w234`.

