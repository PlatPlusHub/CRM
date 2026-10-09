# Change Request — SPEC-250

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make every writer of a tenant's subscription state judge canon 26 on the row it replaces, closing **SUB-4** and the new **SUB-5** with one migration, a permanent two-session proof and a CI tripwire.

The three writers are `app.platform_activate_subscription`, `app.platform_transition_subscription` and the scheduled `app.process_subscription_lifecycle`. After this change, each one locks its subscription row before it judges the transition. The judgement, the write and the recorded event then describe the same state under concurrency, as well as in sequence.

This contract does not touch the subscription state machine, plans, billing, payment proofs, activation-code issuance or redemption, the surface dispositions, n8n or any Phase-8 work.

## Business Reason

### Authority
- **The owner's 2026-10-08 directive** (SPEC-248) schedules the SUB-4 correction ahead of Batch 6 Slice 35, to close before the first production subscription. The owner's 2026-10-09 decision includes the scheduled lifecycle job (Case C) in the same bounded correction. All three state-changing paths share one invariant: acquire the lock before evaluating the current state, then transition and emit the event from the locked state.
- **Canon 26** (`app.subscription_transition_allowed`):
  - `trial -> expired` and `active -> grace_period` are the lifecycle job's;
  - `grace_period -> read_only` is "Two-day grace period ends";
  - renewal is `grace_period`, `read_only`, `expired` or `cancelled` `-> active`, and `suspended -> active` is the Platform Owner's restoration;
  - there is no `active -> suspended` and no `active -> read_only`.
- **LIC-4 (SPEC-247):** suspension and cancellation revoke a tenant's outstanding activation code. A redemption locks its code row and then the subscription.
- **`202607056900`:** the lifecycle job skips and records a failing tenant and never raises, so one tenant's subscription never decides every other tenant's.

### What was measured
All runs were on the unrepaired 244-migration schema at `f70e1b3`, on a clean local reset from the main checkout. Each case used two live sessions. The second writer was observed WAITING on the first through `pg_blocking_pids`, never inferred from timing.

| Case | Overlap | Outcome before the repair |
| --- | --- | --- |
| A (SUB-4) | A tenant owner's redemption commits `read_only -> active` while the Platform Owner's suspension waits | The suspension commits `suspended` over `active`. Events: `read_only->active, read_only->suspended` |
| B (LIC-4) | The suspension commits first while the redemption waits | The redemption is refused and the tenant stays `suspended`. LIC-4 already holds |
| C (SUB-5) | A Platform Owner renewal commits `grace_period -> active` while the lifecycle job waits | The job writes `read_only` over the renewed tenant. Events: `grace_period->active, grace_period->read_only` |
| D | The job commits `grace_period -> read_only` while a renewal waits | The renewal is legal, but it records `grace_period` as its from-state |
| E (lock order) | A session holds the tenant's activation-code row while a suspension waits, then activates | The suspension commits `suspended` over `active` |
| F (SUB-4, no code) | A Platform Owner renewal commits while a suspension waits | The suspension commits `suspended` over `active` |

SUB-4 was first measured at `bdf6f1b` (SPEC-247, Case A). Case F matters because the transition's code revocation already serializes Case A behind a redemption, so Case A alone cannot prove the subscription lock.

### Severity
- **SUB-4 (Low, re-measured as SPEC-248 required).**
  - Only the Platform Owner reaches either function, and a suspension is the Platform Owner's own intent.
  - The defect is therefore a canon-26 breach and a false audit trail, not a loss.
  - Activation (Case D) records a false from-state and nothing worse.
- **SUB-5 (Medium, latent), a separate id.**
  - A different writer, with no decision behind the outcome. The scheduler demotes a tenant that has just renewed, and so has paid.
  - That tenant loses write access until the Platform Owner acts again, and the event is false.
  - The window is a renewal that overlaps the daily 00:10 run.
  - Primary holds 0 tenants, 0 subscriptions, 0 activation codes and 0 events, so both defects are latent.

### The repair
One migration replaces the three function bodies, and nothing else:
- **Activation and transition:** the existing `select … from public.subscriptions where tenant_id = … order by created_at desc limit 1` gains `for no key update`, so the function judges the row it locked.
- **Transition, lock order:** the LIC-4 revocation block moves from after the canon-26 check to the top of the function. Codes are therefore locked before the subscription, the order a redemption takes. A refused transition raises, and the revocation rolls back with it.
- **Lifecycle job:** inside its existing per-row `begin … exception when others` block, the job re-reads each iterated row with `for no key update` into `v_cur` and judges `v_cur`. The loop's snapshot becomes a candidate list only, and every use of the snapshot's state, dates, period and auto-renew moves to `v_cur`.
- **`for no key update`, not `for update`:** it is exactly the lock each writer's UPDATE already takes, now taken before the judgement. The writers therefore serialize against one another, while a payment proof's foreign-key check (`for key share` on `subscriptions`) is not made to wait.
- **Unchanged:** every signature, owner, `SECURITY DEFINER`, empty `search_path`, ACL and comment. On the parity surface (which strips comments and whitespace), each function differs from its current definition only by the lock clause; the transition also differs by the moved block, and the job by `v_cur`.

The job locks every row it iterates, not only the due ones, so the due rules keep one home. The cost is bounded: a Platform Owner action on a tenant waits at most for the daily job to commit. Every other writer of `subscriptions` is one of these three short definer functions; Test 148 pins that set.

### Rejected
- **`for update`:** it conflicts with `for key share`, so payment-proof inserts would wait on the daily job. Case G kills it.
- **Locking only the rows the snapshot shows as due:** it would restate the due rules outside their one home, and its correctness would rest on an argument about every other writer.
- **`skip locked` or `nowait` in the job:** it would drop a due tenant from a run, or record a spurious finding for a benign overlap.
- **An advisory lock per tenant:** a second mechanism for what the row lock already states.
- **Changing redemption's error message (Case B):** see Held.

### Held, recorded so a later slice does not rediscover it
- **Case B's message.** The revoke-versus-redeem refusal surfaces as the CHECK `tenant_license_activations_not_both_consumed_and_revoked` (23514), not redemption's generic message.
  - SPEC-247 recorded it as a non-finding: only a holder of the real code, mid-race, sees it, and it reveals only that the code was just revoked.
  - Nothing new was demonstrated, so it stays separate and unregistered.
- **The redemption path** is unchanged byte-for-byte: `app.redeem_license_token`, `app.platform_issue_license_token`, `app.platform_revoke_license_tokens` and `app.subscription_transition_allowed`.

## Risks

- **New waiting.**
  - A Platform Owner action, or a redemption, on a tenant whose row the daily job has locked waits for the job to commit.
  - The job waits for a concurrent writer of a row it iterates, including a row that is not due.
  - Every such writer is a short definer function. A lock the job cannot take, such as a deadlock victim, fails that one tenant into a job finding (`202607056900`'s isolation), never the run.
  - Case G proves that payment-proof foreign-key checks are not made to wait.
- **A deadlock** would need a transaction holding two tenants' subscriptions in the opposite order to the job's `tenant_id` order. No such writer exists, and the job's own isolation contains it if one ever appears.
- **Pinned consumers.** Tests 42, 66, 131 and 147 and the HTTP suites pass unchanged (Pre-Approval Evidence).
- **Primary deployment** replaces three function bodies, and nothing else. It requires separate exact-byte owner authorization (Gate 2); approving this contract does not authorize it.
- **Workstation:** resets run from the main checkout, because a reset from a scratch worktree breaks local storage. The main checkout's CRLF working copies make some local function md5 values differ from Primary by CR bytes only; the parity surface strips them.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-250-a-subscription-transition-is-judged-on-the-row-it-replaces.md`
- `supabase/migrations/20261009120000_a_subscription_transition_is_judged_on_the_row_it_replaces.sql`
- `supabase/tests/148_a_subscription_transition_is_judged_on_the_row_it_replaces_test.sql`
- `scripts/verify_subscription_concurrency.py`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607054000_subscription_lifecycle_and_platform_authority.sql`
- `supabase/migrations/202607054100_tenant_license_activation.sql`
- `supabase/migrations/202607056900_a_scheduled_job_may_not_lose_work_silently.sql`
- `supabase/migrations/202607058400_a_single_use_code_is_single_use_under_concurrency_too.sql`
- `supabase/migrations/20261008170000_an_activation_code_carries_the_platforms_current_decision.sql`
- `supabase/tests/42_subscription_lifecycle_test.sql`
- `supabase/tests/66_scheduled_job_isolation_test.sql`
- `supabase/tests/131_platform_authority_cannot_be_granted_test.sql`
- `supabase/tests/147_an_activation_code_carries_the_platforms_current_decision_test.sql`
- `scripts/verify_customer_concurrency.py`
- `scripts/verify_journey_branches.ps1`
- `scripts/verify_api_end_to_end.ps1`
- `scripts/verify_role_journeys.ps1`
- `scripts/verify_database.sql`
- `scripts/parity_surface.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/readiness_population.ps1`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/09_saas_plans_and_access.md`
- `_ORVION_CANONICAL/26_state_machines.md`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/orvion-acceptance.yml`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/26_state_machines.md` (subscription transitions); `_ORVION_CANONICAL/09_saas_plans_and_access.md` (activation code)
- `reports/master/MASTER_GAP_REGISTER.md` (SUB-1 to SUB-4, LIC-2, LIC-4, LIC-5); `reports/master/MASTER_EXECUTION_PLAN.md` (Pre-Production Readiness Closure)
- `changes/SPEC-247-an-activation-code-carries-the-platforms-current-decision.md` (Held; SUB-4)
- `supabase/migrations/202607054000_subscription_lifecycle_and_platform_authority.sql`; `supabase/migrations/202607056900_a_scheduled_job_may_not_lose_work_silently.sql`; `supabase/migrations/20261008170000_an_activation_code_carries_the_platforms_current_decision.sql`
- `scripts/verify_customer_concurrency.py` (the session harness reused)

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

- `pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1`
- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_role_journeys.ps1`
- `python scripts/verify_subscription_concurrency.py`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| The three writers lock their row (`for no key update`) before judging canon 26 | `app.redeem_license_token` (calls activation while holding its code row); the `subscription-lifecycle` cron job; Tests 42, 66, 131, 147; `verify_journey_branches.ps1` (licensing and LIC-4 checks), `verify_api_end_to_end.ps1`, `verify_role_journeys.ps1` | WRITE | The prototype migration (SHA-256 `5d6ecc1f46b7ead278fb1557f39e1192a5dcca0259a3c41d56fc56a2088f8b06`, md5 `f9a4a15f8d3263b852ae88c867431d3e`) was built by anchored edits of the current definitions (`202607054000`, `20261008170000`, `202607056900`). It was applied with its ledger row after a clean main-checkout reset (ledger 245, latest `20261009120000`; storage 68). Text md5: `ae7c5de5…` (activate), `546f01ef…` (transition), `31d6258e…` (lifecycle). Owner `postgres`, SECURITY DEFINER, `search_path=""`, ACLs `{postgres=X, service_role=X}` (lifecycle `{postgres=X}`) and the comment md5s equal Primary's current values, read 2026-10-09. The redemption, issuance and revocation text is unchanged. |
| The transition revokes codes before it locks the subscription, and so before its canon-26 check | LIC-4 (Test 147; the two LIC-4 HTTP checks); a refused transition; the redemption's lock order | WRITE | Test 147 passes 15/15, unchanged, inside Pass A and Pass B; `verify_journey_branches.ps1` 85/0. A rolled-back probe asked to suspend an `active` tenant holding a live code. It was refused `canon 26 does not allow active -> suspended`; the tenant stayed `active` with 1 live code and 0 `license_token_revoked` events, so the revocation rolls back with the refusal. Case B (suspension first) and Case E (code row held, no deadlock) pass. M4 (the reversed order) produced a real `deadlock detected`. |
| The lifecycle job locks every iterated row until it commits, inside its per-row exception block | Platform Owner actions and redemptions on a locked tenant; payment-proof inserts (`subscription_payment_proofs_subscription_id_fkey`, `for key share`); job fault isolation (Test 66); duplicate or false events | WRITE | Case C: the job waited on a renewal, then left the tenant `active` with the single event `grace_period->active`. Case D: both moves were legal, with events `grace_period->read_only,read_only->active`. Case G: the RI statement's `for key share` completed while the job held the row, and a third writer was observed waiting on the job. No proof tenant gained a lifecycle job finding. Test 66 passes unchanged. `cron.job` `subscription-lifecycle` runs at `10 0 * * *` on Primary and locally. |
| Test 148, a CI tripwire | `supabase test db` in Migration CI and ORVION Acceptance; Check 15 suite figures | WRITE | Test 148 (SHA-256 `ec160be88c2e4dd40f51b202b2de04f97859e34db0a0b696d4c92f42c3cda080`, `plan(8)`) passes 8/8 on the repair, in Pass A and Pass B. On the unrepaired bodies it fails assertions 1–6, each for its intended reason. |
| `scripts/verify_subscription_concurrency.py`, a permanent two-session proof | `-Finish` (DATABASE, Additional Verification, after the HTTP suites and before Pass B); `scripts/verify_customer_concurrency.py` (imported, unchanged) | WRITE | SHA-256 `acb2b3dfb15e7cc7eb418f4be5a609244953b3f885eb8974906c3593d4969d45`. On the repair it reports `8 passed, 0 failed` in about 15 seconds, on a stack the six HTTP suites had already dirtied, and Pass B passes after it. On the unrepaired schema it reports `2 passed, 6 failed` (the causal negative). Each case runs on its own tenant, and a failing case is reported without aborting the run. The pre-existing `Exception ignored … Errno 22` at interpreter exit comes from the shared harness and does not change the exit code. |
| The generated API contract | `MASTER_API_CONTRACT.md` | WRITE | The canonical generator on the prototype reports 80 RPC endpoints (80 with HTTP evidence), 8 views and 74 tables, byte-identical to the committed contract (SHA-256 `d28fb5672ca9c0795a99a74746069c973e1392edcc5e3d2a5a315348138175fd`). No signature, grant or table moves. Step 7 regenerates it, and it stays unchanged. |
| Suite, HTTP and smoke | full pgTAP; the six HTTP suites; `scripts/verify_database.sql` | VERIFY | Run on the frozen bytes in `-Finish`'s order on a main-checkout reset, logged by `scripts/run_timed.ps1` (7.1 min, `concurrent=0`, head `f70e1b3`): pgTAP Pass A 147 files / 2689 PASS, plus Test 148 8/8; HTTP 35 + 40 + 85 + 122 + 122 + 60 = 464 passed, 0 failed; the two-session proof 8/0; Pass B 147 / 2689 PASS, plus Test 148 8/8; smoke `ALL CHECKS PASSED (78 tables, … 71/622 catalog, …)`. The plan sum with Test 148 is 148 files / 2697. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | The local prototype, against the recorded Primary values (244, `9e846936…`): functions `127430f783d23b2b89e474636be684c9`/320 → `258738c5fea4dd5ff1040cf65997390b`/320; combined `bb42b1b7a8ee985d892ccaf4426ce4ce`/3109 → `902311907ba7e192b285bd43e091ff8d`/3109. Triggers, policies, constraints, grants, columns, views, indexes, status transitions and RLS are unchanged. The 245-entry ledger fingerprint is `43bf5befaf466ec422d8eaaf5261d250`. |
| Measured state that moves | manifest (`Live state`, suite figure, Current Module, Last Completed, Next capability); `primary-ledger-evidence.json`; `ai-map.json` | WRITE | 244 → 245 migrations, latest `20261009120000`; 147 → 148 files and 2689 → 2697 assertions; HTTP stays at 464. Tables (78), catalog (71/622), client RPCs (80), coverage (35 of 78) and the dispositions do not move. Primary values are written only from fresh post-deploy readings. |
| SUB-4 fixed and re-measured; SUB-5 added and fixed | `MASTER_GAP_REGISTER.md`; Checks 11, 21, 25; `scripts/readiness_population.ps1` | WRITE | With the edits applied in a scratch worktree at `f70e1b3`, the readiness derivation reads 447 ids, 324 settled. It names SUB-4 among the "settled ids the section names … closed since the reading" (exit 0), so the execution plan's dated reading needs no edit. Both rows' Owner Decision field is `—`, so Check 25 reads no owner decision. |
| CI-only guard self-tests and repository consistency | `scripts/test_*_guard.ps1` (four); `scripts/check_repository_consistency.ps1` | VERIFY | Measured in the same worktree with Steps 1–3 applied. Repository consistency reports exactly the pre-deploy drift (6 issues): `manifest says 244 migrations, repository holds 245`; latest `20261008170000` vs `20261009120000`; fingerprint `9e846936…` vs `43bf5bef…`; `147 test files` vs 148; `2689 assertions` vs 2697; RECOVER-1. Of the four guard self-tests (12.5 min), future-date (18/0) and status-contradiction (33/0) pass. Primary-ledger (11 passed, 2 failed) and cold-start (25 passed, 9 failed) fail ONLY their CONTROL and restore cases, which require an untouched copy of the repository to be CLEAN; every mutation case passes. These are not waived: Step 7 makes them true, and Step 8 requires them green. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| The frozen bytes carry the Pre-Approval evidence: clean reset, Test 148, pgTAP A/B, the six HTTP suites, the two-session proof, smoke and the mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| SUB-4 and SUB-5 describe the local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite figures equal the test files | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |
| The four CI-only guard self-tests pass | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism:
- The row lock that each writer's UPDATE already takes, now taken before the judgement.
- The lifecycle job's per-row exception block (`202607056900`).
- The two-session harness of `scripts/verify_customer_concurrency.py` (`Session`, `psql`, `wait_blocked`), imported unchanged.
- `-Finish`'s DATABASE slot for `scripts/verify_*` commands named in Additional Verification.
- `supabase test db`, which Migration CI and ORVION Acceptance already run.

Nothing else is added: no table, column, trigger, permission, policy, grant, event type, catalog value, workflow or capability. Rejected: `for update`; locking only rows the snapshot shows as due; `skip locked` or `nowait`; an advisory lock.

Added Property: Under concurrency, each of the three subscription writers judges canon 26, writes and records its event on the state it locked. A transition canon 26 forbids against the committed state is refused, never written. The lifecycle job leaves a tenant renewed while it waited alone. Codes are always locked before the subscription. Payment-proof foreign-key checks are not made to wait.

Causal Negative:
- **On the unrepaired 244-migration schema at `f70e1b3`:** `scripts/verify_subscription_concurrency.py` (frozen bytes) reported `2 passed, 6 failed`.
  - A, E and F each committed `suspended` over `active` (`read_only->active,read_only->suspended`).
  - C left the renewed tenant `read_only` (`grace_period->active,grace_period->read_only`).
  - D recorded `grace_period->read_only,grace_period->active`.
  - G found no lock to observe.
  - B and fault isolation passed.
- **Test 148** on the unrepaired bodies failed assertions 1–6.

Positive Test Design:
- Legal transitions still commit: a renewal from `grace_period` and from `read_only`, and a Platform Owner `active -> grace_period`. Each records exactly one event with a true from-state.
- The LIC-4 suspension still wins over a waiting redemption (Case B).
- A payment proof's foreign-key check (`for key share`) completes while the job holds the row (Case G).
- No overlap produces a lifecycle job finding.
- Tests 42, 66, 131 and 147 and the HTTP suites pass unchanged.

Negative Test Design:
- **The two-session proof.** For every case, the waiter is observed blocked (`pg_blocking_pids`) before the holder commits.
  - A, E and F: the waiting suspension is refused with `canon 26 does not allow active -> suspended`, the tenant stays `active`, and the only event is the true one.
  - C: the job leaves the tenant `active` with the single event `grace_period->active`.
  - D: the events are `grace_period->read_only,read_only->active`.
  - E: no `deadlock detected`.
- **Test 148** pins the shape in CI:
  1–2. both Platform Owner writers lock the row they judge;
  3. the revocation precedes the subscription lock;
  4. the job re-reads under its lock;
  5. the job never judges its snapshot;
  6. the job's lock is the first statement of its per-row exception block;
  7. no writer takes `for update`;
  8. the three writers are still the only functions that update `public.subscriptions`.

Non-Empty Population Obligation:
- Each two-session case creates its own committed tenant, with a subscription in the state the case needs. Cases A, B and E add an owner user and a live activation code. Cases C and D use a `professional` subscription whose grace ended a day earlier.
- Test 148 reads three existing function bodies, and assertion 8 the whole `app`, `public` and `reporting` function population.

Mutation Obligation: Out of file, record the md5 of each of the three functions' text. For each mutant:
1. Install it and prove the hashes differ.
2. Run the two-session proof and Test 148, and record each one's failing cases or assertions.
3. Restore it and prove the hashes equal the base.

A mutant whose installation is not proven is a harness error, never a kill.

| Mutant | Change | Proof fails | Test 148 fails |
| --- | --- | --- | --- |
| M1 | the transition reads without a lock | F | 2 |
| M2 | activation reads without a lock | D | 1 |
| M3 | the job re-reads without a lock | C, G | 4, 6 |
| M4 | the transition locks the subscription before revoking codes | E (`deadlock detected`) | 3 |
| M5 | every writer takes `for update` | G | 1, 2, 4, 6, 7 |
| M6 | the job judges its snapshot's state | — | 5 |
| M7 | the job locks outside its per-row exception block | — | 6 |
| M8 | a fourth function updates `public.subscriptions` | — | 8 |

Prototype result, on the frozen bytes: the base hashes are `ae7c5de5… 546f01ef… 31d6258e…` (activate, transition, lifecycle). Every installation changed them, and every restoration returned them. All eight mutants were killed, exactly as expected.
- **The two-session proof** failed:
  - M1 [F];
  - M2 [D];
  - M3 [C, G];
  - M4 [E, `deadlock detected`];
  - M5 [G, `canceling statement due to lock timeout` on the key-share check].

  The other cases passed each time, and the repair re-proved 8/0 afterwards.
- **Test 148** failed:
  - M1 [2]; M2 [1]; M3 [4, 6]; M4 [3];
  - M5 [1, 2, 4, 6, 7]; M6 [5]; M7 [6];
  - M8 [8], where M8 is a function `app.zz_m8_writer` that updates `public.subscriptions`, installed and then dropped.

  It failed [1–6] on the unrepaired bodies and passed 8/8 after every restoration.

Post-Implementation Proof Obligation: All of the following, on the final bytes:
- **Through canonical `-Finish`:** a clean reset from the main checkout, pgTAP Pass A (including Test 148), the three HTTP suites and the two-session proof named in Additional Verification, pgTAP Pass B and smoke.
- **The Pre-Approval evidence,** carried by byte-identity (Step 4): the full six-suite run, the causal negative and M1–M8.
- **The checks:** the generated artifacts, the four CI-only guard self-tests, repository consistency and `git diff --check`.
- **Primary:** fresh Primary evidence, parity evidence and the Primary ledger check.

## Implementation Steps

1. **Check** that `supabase/migrations/20261009120000_a_subscription_transition_is_judged_on_the_row_it_replaces.sql` is absent.
   - If absent, create it LF, byte-identical to the prototype: SHA-256 `5d6ecc1f46b7ead278fb1557f39e1192a5dcca0259a3c41d56fc56a2088f8b06`, md5 `f9a4a15f8d3263b852ae88c867431d3e`, 13678 bytes, 274 LF, 0 CR.
   - Its two non-ASCII bytes are the `§` of an existing comment in `app.platform_activate_subscription`, kept verbatim.
   - Its statements are three `create or replace function` statements, for `app.platform_activate_subscription`, `app.platform_transition_subscription` and `app.process_subscription_lifecycle`, preceded by a comment block stating SUB-4, SUB-5 and the lock order.
   - If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/148_a_subscription_transition_is_judged_on_the_row_it_replaces_test.sql` and `scripts/verify_subscription_concurrency.py` are absent. If absent, create each LF, ASCII and byte-identical to the prototype:
   - Test 148: SHA-256 `ec160be88c2e4dd40f51b202b2de04f97859e34db0a0b696d4c92f42c3cda080`, 4156 bytes, `select plan(8);`;
   - the proof: SHA-256 `acb2b3dfb15e7cc7eb418f4be5a609244953b3f885eb8974906c3593d4969d45`, 10859 bytes.

   If a target exists with different bytes, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` already contains a `| SUB-5 |` row. If not, make these edits and nothing else:
   - a 2026-10-09 SPEC-250 freshness entry, with the SPEC-248 one demoted to `Previously:`;
   - the SUB-4 row:
     - rewritten FIXED by SPEC-250 locally, with Primary pending, `Mig` `M` and Cert `🛡`;
     - severity Low, re-measured, with the measurements above;
     - its Owner Decision field `—`, its Source unchanged and its Updated date `10-09`;
   - a new SUB-5 row directly below it: Medium, FIXED locally with Primary pending, Cert `🛡`, Source this contract.

   If the register carries content other than its `f70e1b3` bytes, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, record it, running no command that `-Finish` runs:
   - **Byte identity.** The three new files equal their frozen SHA-256 values, so the Pre-Approval evidence (the clean reset, pgTAP A/B, the six HTTP suites, the two-session proof, smoke, the causal negative and M1–M8) is evidence about exactly these bytes.
   - **The narrow check.** Test 148 alone (`npx supabase test db supabase/tests/148_a_subscription_transition_is_judged_on_the_row_it_replaces_test.sql`) passes against the local stack.
   - **Scope.** `git status` shows changes only to Write Scope paths.
   - **A fresh Primary baseline, read-only:**
     - the project URL, the full ordered ledger and the absence of the target migration;
     - the function and structural surfaces;
     - the three functions' text md5, security mode, owner, `search_path`, ACL and comment;
     - the tenant, subscription, activation-code, payment-proof, event and job-finding counts.

   Record the predicted delta.
5. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 4 and present the Gate-2 package. Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261009120000_a_subscription_transition_is_judged_on_the_row_it_replaces`. If it is absent and deployment is separately authorized:
   - **Recheck.** Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts and the three functions' md5.
   - **Write.** On an exact match, prove the transmitted text's md5 server-side, then apply only the authorized migration through the Primary connector.
   - **Rename, if needed.** If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row, its stored statement md5 equal to the file's, and no existing target version.
   - **Read fresh:**
     - the ledger, the function surface and all ten structural surfaces;
     - the three functions' definitions, security modes, owners, `search_path`, ACLs and comments;
     - the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - **Evidence.** Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - **Manifest `Live state`.** Set it from the same readings, the verification date and the 464 HTTP assertions' Pre-Approval date.
   - **Suite figure.** Confirm that `supabase/tests` holds 148 files whose literal `plan(N)` values sum to 2697, then set `Suite **148 files / 2697 assertions**`. If either differs, stop.
   - **Register.** Mark SUB-4 and SUB-5 `DEPLOYED` with Cert `✅`, worded without a date beneath the register's freshness line.
   - **Generated files.** Regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` (stored LF) with the canonical generators.
   - **Guards.** Run the four `scripts/test_*_guard.ps1` and require each to pass.
   - **Checkpoint.** Set the Runtime Checkpoint to DONE, so Step 8's `-Finish` runs in VERIFY mode.

   If Primary is unproven, stop.
8. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, do all of the following in the Complete commit:
     - transition to Complete and clear `Active Change Request`;
     - run `scripts/batch6_select_target.ps1` and record its Top-12;
     - set `Last Completed` to SPEC-250;
     - in `Current Module`, replace the SUB-4 clause with Batch 6 resuming at Slice 35;
     - set `Next capability` to **Foundation Completion Programme — Batch 6 Slice 35**, naming the measured first target, followed by the existing Phase-8 order, closed-chapter and standing-fact sentences unchanged;
     - keep the manifest within 7000 characters;
     - regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate with `scripts/publish_candidate.ps1` and require exact-SHA candidate CI.
   - Promote the same accepted SHA, require main CI, and run `-Certify` for `REMOTE_CERTIFY: READY`.
   - Verify synchronized clean refs.

## Acceptance Criteria

- [ ] `app.platform_activate_subscription` and `app.platform_transition_subscription` lock the subscription they judge (`for no key update`), and the transition revokes codes before that lock. A transition canon 26 forbids against the committed state is refused, and a refused transition revokes nothing.
- [ ] `app.process_subscription_lifecycle` re-reads each iterated row under `for no key update`, inside its per-row exception block, and judges only that row. A renewal committed while it waited is left `active` with one true event.
- [ ] Every recorded subscription event names the state actually replaced, in Cases A, C, D and F.
- [ ] Legal transitions, LIC-2, LIC-4 and LIC-5 are preserved: Case B holds, Tests 42, 66, 131 and 147 pass unchanged, and the redemption, issuance, revocation and transition-rule functions are byte-identical.
- [ ] A payment proof's foreign-key check is not made to wait by the job (Case G), no overlap creates a job finding, and Case E proves the lock order without a deadlock.
- [ ] The three functions keep their signatures, owner, `SECURITY DEFINER`, empty `search_path`, ACLs and comments.
- [ ] `scripts/verify_subscription_concurrency.py` runs all seven cases plus fault isolation, each independently, and is named in Additional Verification. Test 148 runs in every CI database job.
- [ ] Mutants M1–M8 are each killed, with installation and restoration proven, and the causal negative is recorded.
- [ ] SUB-4 (Low) and SUB-5 (Medium) are FIXED and DEPLOYED in the register. Case B's message stays the non-finding SPEC-247 recorded, and no other row changed.
- [ ] The migration, Test 148 and the proof matched their frozen SHA-256 values when applied.
- [ ] Primary, the recorded evidence, the manifest (245 migrations; 148 files / 2697 assertions), the API contract and `ai-map.json` agree, and the four CI-only guard self-tests pass.
- [ ] The manifest names Batch 6 Slice 35 and its measured target as the next capability, with no Active Change Request.
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration, plus at most the one guarded ledger rename, with no business-data write. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-10-09 — Owner-authorized approval and execution start

The owner's 2026-10-09 decision approved including the scheduled subscription lifecycle job (Case C) in this bounded SUB-4 correction. It authorized Draft → Approval → In Progress → Implementation → Local Verification → Review under the canonical lifecycle and the frozen Write Scope, with a full database verification. It stops at Human Gate 2 before any Primary write and does not authorize deployment.
- Draft `0828e1b`. A read-only evaluation of it returned `APPROVAL_EVIDENCE: PASS`, with 9 Write Scope paths and profiles DATABASE and REPOSITORY.
- Approved at `32c9fbd`; its pre-commit Gate reported `APPROVAL_EVIDENCE: PASS`.
- In Progress from this commit, at Resume Step 1. Primary stays read-only until Gate 2; Secondary `brplkqmbzffpxqgkkdzo` is never contacted.
## Verification Notes

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created or deleted.
- [ ] No section was added, removed or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

- **LEARN BEFORE GUESSING.** All six prototype cases were reproduced on the current baseline before anything was designed. The writer set, the foreign key to `subscriptions` and the cron schedule were read from the catalog. That reading changed the lock from `for update` to `for no key update`.
- **EARN IT.** SUB-4 and SUB-5 were reproduced with two live sessions and an observed blocking edge, and both were killed by their mutants.
- **WORTH IT.** A paying tenant demoted by the scheduler, and a canon-forbidden suspension with a false audit trail, before the first production subscription.
- **SIMPLIFY IT WITHOUT WEAKENING.** One lock clause per writer, one moved block and the existing harness. The pre-deploy step proves byte-identity instead of re-running what `-Finish` runs.
- **Owner authorization (2026-10-09).** The owner approved including Case C and authorized Draft through Review under the canonical lifecycle, stopping at Gate 2. It authorizes no Primary write.
- **Deliberately not changed:**
  - Case B's constraint-named message;
  - redemption, issuance and revocation;
  - the state machine, plans, billing and payment proofs;
  - the surface dispositions (no slice is audited here) and the execution plan's dated readiness reading, whose derivation reports SUB-4 as closed since the reading;
  - n8n and Phase 8;
  - the registered worktrees `owt/p2` and `C:\w234`.
