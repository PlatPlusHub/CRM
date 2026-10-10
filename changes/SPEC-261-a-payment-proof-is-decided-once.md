# Change Request — SPEC-261

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Close **SPP-6**: make `app.platform_review_payment_proof` decide a subscription payment proof once under concurrency, as it already does in sequence. Correct the stale "not measured" record of the race.

After this change one invariant holds: **a payment proof is judged `pending` on the row the review has locked, so of two concurrent reviews of one proof exactly one decides it, and the other is refused by the existing check.**

The repair is one lock clause in one function body. Under the owner's 2026-10-10 direction this corrective contract is taken ahead of Batch 6 Slice 39. It does not touch SPP-3 (the platform reviewer's identity), the upload, activation semantics, any grant, policy, trigger, constraint, canon document, n8n or any Phase-8 work.

## Business Reason

### Authority
- **The owner's 2026-10-10 directions.**
  - The SPEC-260 Gate-2 authorization required the reproduced review race to be assessed by priority before ordinary Batch 6 selection resumes. It forbade silently expanding SPEC-260, coupling the race to SPP-3 or inventing a platform reviewer identity.
  - The follow-up authorization covers PLAN, renewed investigation, local prototyping and this Draft. It stops at Gate 1 and does not authorize a Primary write.
- **The selector stays as measured.** After SPEC-260 it ranks `complaints` (8/48) first for Slice 39. This contract records no Batch 6 slice and changes no coverage. It is a priority exception for a measured entitlement defect, and Slice 39 follows it.
- **Canon 26's approval machine:** `pending -> approved / rejected / cancelled`, with `rejected -> pending` for resubmission. It has no `rejected -> approved` and no second decision.
- **Canon 28:** "Subscription proof review is platform owner action."
- **The review** (WP-04-B, `202607054500`) decides only a `pending` proof: "a second approval of the same proof is refused rather than silently re-activating a subscription". `47_…` assertion 16 pins that, for sequential reviews only.

### What was measured
All runs used the local stack, on the certified 248-migration schema at `39ab45a`, with two live sessions.
- Each review ran as `service_role`, the platform's path.
- The second review was observed WAITING on the first through `pg_blocking_pids`, never inferred from timing.
- Each fixture tenant held one pending proof uploaded through `app.upload_subscription_payment_proof`.

| Race | Overlap | Outcome before the repair |
| --- | --- | --- |
| H | An approval with terms (`professional`, `annual`) commits while a rejection waits | The proof ends `rejected` while the subscription is `active`/`annual`. Events: approved, activated, then rejected "from `pending`". Security events: `approved,rejected` |
| I | A rejection commits while an approval with terms waits | The rejected proof ends `approved` and the subscription is activated `annual`. Events: rejected, approved "from `pending`", activated. Security events: `rejected,approved` |
| J | Two approvals with terms (`annual`, then `monthly`) | Two approvals and two activations, the second `active -> active`. The subscription ends on the second reviewer's `monthly` terms. Security events: `approved,approved` |

**The mechanism.** The review reads the proof without a lock, judges `pending` on that read, and updates the row by id alone. Under READ COMMITTED the second review reads the first's uncommitted row as `pending`. It waits only at its UPDATE, on the first's row lock. When the first commits, `where id = …` still matches, so the second rewrites the decided row and records a decision "from `pending`" that the row no longer held.
- H and J were first reproduced during SPEC-260 (its Begin entry, observation 2), from a read-only tenant. I is new.
- All three were re-measured here twice: from a read-only tenant and from a tenant paying in its grace period, with the same outcomes.

### Severity: SPP-6, Medium, latent
- **What is actual:**
  - the paid entitlement and the recorded payment decision disagree (H);
  - a payment the platform rejected is accepted, and paid access is granted (I);
  - one payment is decided twice, and the second reviewer's terms replace the first's (J).

  Each case also leaves a false from-state and duplicated decision and security events. Unlike SUB-4, whose outcome was the Platform Owner's own intent, no single decision explains the final state. Like SUB-5 (Medium), it is an entitlement consequence with no decision behind it.
- **What is not actual:**
  - Only `postgres` and `service_role` execute the review. No tenant can reach it (`47_…` 13, `131_…`).
  - No platform console, Edge Function or script calls it; the repository's only callers are tests.
  - It needs two reviews of one proof overlapping inside the first's transaction, from two platform operators or a retried call.
  - Primary `vrvtsxexkiiiivlkdxzp` holds 0 payment proofs (read 2026-10-10 after SPEC-260's deployment).

  It is therefore not High, which the register reserves for tenant-reachable breaches such as SPP-1/SPP-2.
- **Identity.** `SPP-6` is the next free id of the family. `SPP-4` appears only as a corruption artifact in `reports/history/session-2026-08-30-subscription-licensing-audit.md` and is not reused. Neither `SPP-6` nor `SPEC-261` appears on `origin/main`.

### The repair
One migration replaces the body of `app.platform_review_payment_proof`. Its one read of the proof gains `for no key update`:

```
    select id, tenant_id, subscription_id, status_code
      into v_proof
    from public.subscription_payment_proofs
    where id = p_proof_id
    for no key update;
```

- Comments and whitespace aside, that clause is the function's whole difference from `202607054500`. It is the lock the UPDATE below already takes, taken before the judgement instead of after it. A waiting review re-reads the committed row, and the existing check refuses it: "payment proof is already approved, only a pending proof can be reviewed" (23514).
- **Unchanged:** the signature; SECURITY DEFINER; owner `postgres`; `search_path=""`; ACL `{postgres=X/postgres,service_role=X/postgres}`; no comment; the update, the event and security-event contracts, and the delegation to `app.platform_activate_subscription`.

### Rejected, with the evidence
- **An atomic conditional UPDATE** (`… where id = p_proof_id and status_code = 'pending' returning …`, then a diagnostic read for the refusal message). It was prototyped and passed all 15 cases of the proof, so it is equally correct. It changes 12 code lines instead of one, moves the canon-26 check out of its commented home, and adds a second read whose only job is the message. It takes the same lock in the same order, so it buys no guarantee.
- **`for update`:** mutant M2. It conflicts with the `for key share` that a `document_links` foreign-key check takes on the proof. While a review was open, a link's key-share check on the held proof ended `canceling statement due to lock timeout`.
- **`skip locked` or `nowait`:** mutants M4 and M5. The waiting review is answered "unknown payment proof" or a lock error instead of the canon-26 refusal.
- **An advisory lock, a status-transition trigger or a separate state machine:** each is a second mechanism for what the row lock already states. A BEFORE UPDATE trigger would also reach the session-less direct UPDATE door, which is not this defect.
- **Coupling to SPP-3:** the race needs no reviewer identity. SPP-3 stays owed on its own trigger.

### Lock order and deadlock
- **The writers of `subscription_payment_proofs`,** read from the catalog: `app.upload_subscription_payment_proof` inserts a new row, and `app.platform_review_payment_proof` is the only function that updates one (`153_…` assertion 4 pins this).
- **Foreign keys:** `document_links → subscription_payment_proofs` and `subscription_payment_proofs → subscriptions`. Their checks take `for key share`, which `for no key update` admits.
- **Explicit row locks:** no migration takes one on a proof row.
- **Order:** the review locks the proof, then the subscription inside `app.platform_activate_subscription`. The unrepaired UPDATE already imposed that order; the repair only takes the first lock earlier. No writer of `subscriptions` touches a proof, so nothing takes the reverse order.
- **Measured:**
  - **Case M:** a review whose subscription the lifecycle job held locked the proof, waited on the subscription and completed after the job, without a deadlock.
  - **Two different proofs of one tenant, ad hoc:** the second review waited on the first's transaction (`transactionid` ShareLock, at the subscription). Each proof was decided once, with no deadlock.

### Held, recorded so a later slice does not rediscover it
- **Two different proofs, both approved, each activate the subscription,** and the later terms stand, with `ends_at` from that activation. These are two decisions on two payments under `app.platform_activate_subscription`'s unchanged semantics, identical in sequence, and not this race. No canon rule is shown broken, so no finding is invented.
- **The direct UPDATE door:** `authenticated`'s UPDATE is refused by RLS (REVIEW_SUBSCRIPTION_PAYMENT is held by no role, SUB-3), and `service_role` holds no table UPDATE locally (PAR-5). Unchanged.
- **SPP-3:** the platform's decision still records no reviewer. It stays owed on its trigger, a second platform operator or a platform console.

## Risks

- **New waiting.** A second review of the same proof now waits at its read instead of at its UPDATE, for the same lock and the same duration, and is then refused instead of overwriting.
  - A tenant's upload is not made to wait by an open review (case L).
  - A document link's key-share check on the held proof is not made to wait either (case L, M2).
  - Reviews of different proofs do not wait on each other's proofs.
- **Error behaviour.** The refused review raises the existing 23514 message and rolls back whole. A review that rolls back releases its waiter, which then decides once (case K). A review whose activation fails rolls back its decision (case N).
- **Pinned consumers.** Tests 47, 131, 148 and 152 pass unchanged, and the whole suite passes (Pre-Approval Evidence).
- **Primary deployment** replaces one function body, and nothing else. It requires separate exact-byte owner authorization (Gate 2); approving this contract does not authorize it.
- **Workstation:** resets run from the main checkout, because a reset from a scratch worktree breaks local storage.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-261-a-payment-proof-is-decided-once.md`
- `supabase/migrations/20261010210000_a_payment_proof_is_decided_once.sql`
- `supabase/tests/153_a_payment_proof_is_decided_once_test.sql`
- `supabase/tests/152_a_payment_proof_is_born_pending_and_unreviewed_test.sql`
- `scripts/verify_subscription_concurrency.py`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607054500_subscription_payment_proof_lifecycle.sql`
- `supabase/migrations/202607058900_who_did_this_is_derived_never_accepted.sql`
- `supabase/migrations/20261009120000_a_subscription_transition_is_judged_on_the_row_it_replaces.sql`
- `supabase/migrations/20261010160000_a_payment_proof_is_born_pending_and_unreviewed.sql`
- `supabase/tests/47_payment_proof_lifecycle_test.sql`
- `supabase/tests/131_platform_authority_cannot_be_granted_test.sql`
- `supabase/tests/148_a_subscription_transition_is_judged_on_the_row_it_replaces_test.sql`
- `supabase/tests/49_document_retention_test.sql`
- `supabase/tests/52_public_api_and_executor_contract_test.sql`
- `supabase/tests/60_storage_backlog_observability_test.sql`
- `scripts/verify_customer_concurrency.py`
- `scripts/verify_journey_branches.ps1`
- `scripts/verify_api_end_to_end.ps1`
- `scripts/verify_role_journeys.ps1`
- `scripts/verify_database.sql`
- `scripts/parity_surface.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/09_saas_plans_and_access.md`
- `_ORVION_CANONICAL/26_state_machines.md`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/orvion-acceptance.yml`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/26_state_machines.md` (approval machine); `_ORVION_CANONICAL/28_permissions_matrix.md` (Subscription permissions, Notes)
- `reports/master/MASTER_GAP_REGISTER.md` (SPP-1/SPP-2, SPP-3, SPP-5, SUB-4, SUB-5); `reports/master/MASTER_SURFACE_DISPOSITION.md` (`subscription_payment_proofs`)
- `changes/SPEC-260-a-payment-proof-is-born-pending-and-unreviewed.md` (Begin entry, observation 2; the Gate-2 direction); `changes/SPEC-250-a-subscription-transition-is-judged-on-the-row-it-replaces.md`
- `supabase/migrations/202607054500_subscription_payment_proof_lifecycle.sql`; `supabase/migrations/20261009120000_a_subscription_transition_is_judged_on_the_row_it_replaces.sql`
- `scripts/verify_subscription_concurrency.py` and `scripts/verify_customer_concurrency.py` (the harness extended)

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

- `python scripts/verify_subscription_concurrency.py`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| The review locks the proof (`for no key update`) before its `pending` check | `app.platform_review_payment_proof`'s callers: `service_role`, `postgres`, tests 47, 131 and 152 | WRITE | The prototype is the scratch worktree `wt261` at `39ab45a`. Migration SHA-256 `fa652cddd384989256ddbdef593486b51a7bb23739ae1639c5ab83a342a9ca1c`, md5 `2539aa91d9bff705475fb465eaad33c4`, 4714 bytes, 94 LF, 0 CR, ASCII. It was applied with its ledger row on a stack reset from the main checkout (ledger 249, latest `20261010210000`, storage 68). The function's `prosrc` md5 moves from `e39345fdbfc8e1454cc5f924902cdc11` to `2cbc94867ea6ce5dc81cf5cd98511b25`. Owner `postgres`, SECURITY DEFINER, `search_path=""`, ACL `{postgres=X/postgres,service_role=X/postgres}`, identity arguments and result are unchanged, and the function still has no comment. Comment-stripped, the only code difference from `202607054500` is `where id = p_proof_id;` becoming `where id = p_proof_id for no key update;`. |
| Concurrent reviews of one proof: one decides and the other is refused | the two-session proof; register SPP-6 | WRITE | `scripts/verify_subscription_concurrency.py` (SHA-256 `3c13a698f0db1ee2c237086bf7c248a1b7d4bc5e26b262dda729abced06949df`, 19491 bytes, 418 LF, ASCII). On the repair it reports `15 passed, 0 failed` in about 35 seconds: the seven SPEC-250 cases unchanged, the seven new cases H–N and fault isolation. Each case uses its own tenant and is reported without aborting the run. Every new waiter is observed through `pg_blocking_pids`. The pre-existing `Exception ignored … Errno 22` at interpreter exit comes from the shared harness and does not change the exit code. |
| Lock strength and lock order | uploads (`subscriptions` key share); `document_links` foreign-key checks (proof key share); the lifecycle job and the activation (`subscriptions` row lock) | VERIFY | Case L: an upload and a proof key-share check each finish while a review is open, and a second review waits. Case M: a review waiting on the lifecycle job's subscription lock completes without a deadlock. Ad hoc, two reviews of two proofs of one tenant serialize on the subscription without a deadlock. Writers read from the catalog: one INSERT function and one UPDATE function. No migration takes an explicit lock on a proof row. |
| Test 153, a CI tripwire | `supabase test db` in Migration CI and ORVION Acceptance; Check 15 suite figures | WRITE | SHA-256 `679b869d20dc9cf19597b52daa40b9a3247c375f8fac59df89af7f62959a0531`, `plan(5)`, 3127 bytes, 52 LF, ASCII: 5/5 on the repair. On the unrepaired function it fails assertions 1 and 2. It declares no ATTACK-CLASSES line: test 152 already earns the surface's `ADVERSARIAL` (Check 24 reports all 39 surfaces). |
| Test 152's CONCURRENCY=N/A reason | test 152; Check 24 | WRITE | Comment lines 11–13 only: the stale "its unlocked read is recorded in the disposition row and belongs to SPP-3's trigger" becomes a pointer to SPP-6, the proof and `153_…`. SHA-256 `ab72f9905b4db1181e1413e291a8c1e36f55662d12d080a82a8cbbe2dc87cb8e`, 12334 bytes, 195 LF. Its declaration line, `plan(16)` and assertions are unchanged, and it passes 16/16. |
| The generated API contract | `MASTER_API_CONTRACT.md` | WRITE | The canonical generator on the prototype is byte-identical to the committed contract (`d28fb5672ca9c0795a99a74746069c973e1392edcc5e3d2a5a315348138175fd`): 80 RPC endpoints (80 with HTTP evidence), 8 views and 74 tables. Step 7 regenerates it, and it stays unchanged. |
| Suite and smoke | full pgTAP; `scripts/verify_database.sql` | VERIFY | Run in `-Finish`'s order on a fresh main-checkout reset with the frozen bytes (4.3 min): Pass A `Files=153, Tests=2815` PASS; the proof 15/0; Pass B `Files=153, Tests=2815` PASS; smoke `ALL CHECKS PASSED (78 tables, … 71/622 catalog, …)`. The plan sum is 153 / 2815. The six HTTP suites were not run: none calls the review, which no HTTP producer reaches, so the manifest's 464 HTTP assertions do not move. |
| A proof fixture must leave the stack writable | tests 49, 52 and 60, which upsert a retention policy for every (tenant, document type) in `documents` across all tenants | VERIFY | An earlier draft of the proof left `read_only` tenants owning a payment-proof document. The subscription write gate then refused those upserts, and Pass B failed tests 49, 52 and 60 (2787 of 2815). The new cases now use a tenant paying in its grace period with no grace end, which keeps writes open. Pass B then passes after the proof. SPEC-250's cases are unchanged. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | Against the recorded Primary values (248, `207f3fad…`): functions `b3d4fc61413a43ef1ea60bc27a323b6e`/323 → `724baac791a6a79c7d4328835d800f50`/323; combined `c93fb668bb243fa19274bed2605889ab`/3115 → `5a9ed7ff90852acec9a128b7fe4f8c5a`/3115. The other nine surfaces each equal the recorded Primary value. The 249-entry ledger fingerprint is `323eae75c4a400b4cc6f13317ec21611`. |
| Measured state that moves | manifest (`Live state`, suite figure, Current Module, Last Completed); `primary-ledger-evidence.json`; `ai-map.json` | WRITE | 248 → 249 migrations, latest `20261010210000`; 152 → 153 files and 2810 → 2815 assertions. HTTP (464), tables (78), catalog (71/622), views (8), client RPCs (80) and coverage (39 of 78) do not move. Primary values are written only from fresh post-deploy readings. |
| SPP-6 fixed; the disposition row corrected | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24, 25 | WRITE | **Register:** a SPEC-261 freshness entry (the Slice-38 one demoted to `Previously:`) and row SPP-6 after SPP-5. SPP-6 is Medium, `M`, FIXED locally with Primary pending, Cert `🛡`, Owner `—`, Source SPEC-260 (where it was first reproduced). **Disposition:** an "evidence extended, not re-selected" freshness entry, and the `subscription_payment_proofs` row's session pointer moved to this contract, `SPP-6` added to its findings, its SPP-6 evidence added, and its Next reduced to SPP-3's trigger. The row stays `AUDITED-OPEN` / `ADVERSARIAL`, and coverage stays 39 of 78. Register SHA-256 `4794c75029a98025758d6ac6923891a220eeb40ce757a76339bb2747c0f9d195`; disposition SHA-256 `b355ab2b2c97ba5a069174249d7fcbc94eac2e822d704b2b7f7ebc9ff5011d70`. No other row of either file changed. |
| Repository consistency | `scripts/check_repository_consistency.ps1` | VERIFY | On the prototype, exactly the pre-deploy measured-state drift (7 issues): `manifest says 248 migrations, repository holds 249`; latest `20261010160000` vs `20261010210000`; ledger fingerprint `207f3fad…` vs `323eae75…`; `152 test files` vs 153; `2810 assertions` vs 2815; RECOVER-1 ledger evidence (2). Checks 21 to 28 are clean, and `git diff --check` is clean. These are not waived: Step 7 makes them true, and Step 8 requires them green. |
| CI-only guard self-tests | `scripts/test_*_guard.ps1` (four) | VERIFY | Not run on the prototype, where the drift above can only fail their CONTROL cases. Step 4 runs all four on the working tree, where only that drift may fail. Step 7 runs them on the deployed state, where each must pass. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| The frozen bytes carry the Pre-Approval evidence: clean reset, Test 153, pgTAP A/B, the two-session proof, smoke, the causal negative and the mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| SPP-6 and the disposition row describe the local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite figures equal the test files | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |
| The four CI-only guard self-tests pass | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism:
- The row lock the review's UPDATE already takes, now taken before the judgement.
- The review's existing `pending` check and its 23514 message.
- The two-session harness of `scripts/verify_customer_concurrency.py` (`Session`, `psql`, `wait_blocked`), imported unchanged, and the case runner, fixtures and release logic of `scripts/verify_subscription_concurrency.py`, extended.
- `-Finish`'s DATABASE slot for `scripts/verify_*` commands named in Additional Verification.
- `supabase test db`, which Migration CI and ORVION Acceptance already run.

Nothing else is added: no table, column, trigger, permission, policy, grant, event type, catalog value, workflow, capability, script or framework. Rejected: the conditional UPDATE, `for update`, `skip locked`, `nowait`, an advisory lock and a transition trigger.

Added Property: Under concurrency, `app.platform_review_payment_proof` judges a proof `pending` on the row it has locked. Of two reviews of one proof exactly one decides it, records one decision and one security event, and activates at most once on its own terms; the other is refused with the existing message. A rolled-back review releases its waiter. Uploads and document-link key-share checks are not made to wait, and the lock order (the proof, then the subscription) has no reversed writer.

Causal Negative:
- **On the unrepaired schema at `39ab45a`**, the extended proof (frozen bytes, on a fresh main-checkout reset) reported `11 passed, 4 failed`.
  - H, I and J committed the outcomes in What was measured: `rejected | active/annual`, `approved | active/annual` after a rejection, and `approved | active/monthly` with two activations.
  - L's second review rewrote the approved proof as `rejected`.
  - The seven SPEC-250 cases, K, M, N and fault isolation passed: the controls do not depend on the repair.
- **Test 153** on the unrepaired function fails assertions 1 and 2.

Positive Test Design:
- **Single reviews commit, one session at a time (case N):** a single approval with terms activates `grace_period -> active` once, and a single rejection leaves the subscription untouched. Each records one event and one security event.
- **Error behaviour:** a review whose activation fails (`unknown or inactive plan_code`) rolls back its decision, and the proof stays `pending` and reviewable.
- **A rolled-back review releases its waiter,** which decides once (case K).
- **Case L:** an upload and a key-share check on the held proof finish while a review is open.
- **Case M:** a review waiting on the lifecycle job's subscription completes without a deadlock.
- **Unchanged:** the seven SPEC-250 cases and fault isolation pass, tests 47, 131, 148 and 152 pass, and the reviews run as `service_role`.

Negative Test Design:
- **The two-session proof.** For every race the waiter is observed blocked (`pg_blocking_pids`) before the holder commits. Then:
  - H: the waiting rejection is refused "already approved". The proof stays `approved`, with one approval, one activation, one `approved` security event and `annual`.
  - I: the waiting approval is refused "already rejected". The proof stays `rejected`, with no activation and the subscription `grace_period`.
  - J: the second approval is refused, and the first reviewer's `annual` terms stand with one activation.
  - L: a second review waiting on an open review is refused.
  - N: a sequential replay of a decided proof is refused, for an approved and for a rejected proof.
- **Test 153** pins the shape in CI:
  1. the review's proof read carries `for no key update`;
  2. that lock precedes the `pending` check;
  3. the review takes no `for update`;
  4. the review is still the only function that updates `public.subscription_payment_proofs`;
  5. the review is still SECURITY DEFINER with an empty `search_path`, executable by `service_role` and by neither `authenticated` nor `anon`.

Non-Empty Population Obligation:
- Each new case creates its own committed tenant, with an owner user and a `grace_period` subscription. It uploads a real pending proof through `app.upload_subscription_payment_proof`, whose document, version and link are real rows. Case L adds a second upload, and N a second tenant.
- Test 153 reads the deployed function body and the whole `app`, `public` and `reporting` function population.

Mutation Obligation: Out of file, record the review's `prosrc` md5. For each mutant:
1. Install it by an anchored edit of the live definition and prove the md5 differs.
2. Run Test 153 and the two-session proof, and record the failing assertions and cases.
3. Restore the base definition and prove the md5 equals the base.

A mutant whose installation is not proven is a harness error, never a kill.

| Mutant | Change | Proof fails | Test 153 fails |
| --- | --- | --- | --- |
| M1 | the proof read takes no lock | H, I, J, L | 1, 2 |
| M2 | the lock is `for update` | L (`lock timeout` on the key-share check) | 1, 2, 3 |
| M3 | a lock taken only after the `pending` check | H, I, J, L | 1, 2 |
| M4 | `for no key update skip locked` | H, I, J, K, L | 1 |
| M5 | `for no key update nowait` | H, I, J, K, L | 1 |
| M6 | a second function updates the table | — | 4 |

Prototype result, on the frozen bytes: the base md5 is `2cbc94867ea6ce5dc81cf5cd98511b25`. Every installation changed it, and every restoration returned it: M1 `85a308bf…`, M2 `8863b22e…`, M3 `26f05dfe…`, M4 `9bb01336…`, M5 `ac5f4217…`. M6 is a function `app.zz_m6_writer` that updates the table, installed and then dropped. All six were killed exactly as listed, the other cases passed each time, and Test 153 passed 5/5 on the restored base.

Post-Implementation Proof Obligation: All of the following, on the final bytes:
- **Through canonical `-Finish`:** a clean reset from the main checkout, pgTAP Pass A (including Test 153), the two-session proof named in Additional Verification, pgTAP Pass B and smoke.
- **The Pre-Approval evidence,** carried by byte identity (Step 4): the causal negative and M1–M6.
- **The checks:** the generated artifacts, the four CI-only guard self-tests, repository consistency and `git diff --check`.
- **Primary:** fresh Primary evidence, parity evidence and the Primary ledger check.

## Implementation Steps

1. **Check** that `supabase/migrations/20261010210000_a_payment_proof_is_decided_once.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `fa652cddd384989256ddbdef593486b51a7bb23739ae1639c5ab83a342a9ca1c`, md5 `2539aa91d9bff705475fb465eaad33c4`, 4714 bytes, 94 LF, 0 CR.
   - Its one statement replaces `app.platform_review_payment_proof` with the function above. A comment block precedes it, stating the rule, SPP-6's measurements and the lock order.
   - If the target exists with different bytes, stop.
2. **Check** the three test and proof files. If a target exists with different bytes, stop. Otherwise each must be LF, ASCII and byte-identical to the prototype:
   - **`supabase/tests/153_a_payment_proof_is_decided_once_test.sql`,** if absent: SHA-256 `679b869d20dc9cf19597b52daa40b9a3247c375f8fac59df89af7f62959a0531`, 3127 bytes, `select plan(5);`.
   - **`scripts/verify_subscription_concurrency.py`,** if it carries its `39ab45a` bytes: SHA-256 `3c13a698f0db1ee2c237086bf7c248a1b7d4bc5e26b262dda729abced06949df`, 19491 bytes.
   - **`supabase/tests/152_a_payment_proof_is_born_pending_and_unreviewed_test.sql`,** if it carries its `39ab45a` bytes: SHA-256 `ab72f9905b4db1181e1413e291a8c1e36f55662d12d080a82a8cbbe2dc87cb8e`, which changes only comment lines 11–13.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` already contains a `| SPP-6 |` row. If not, and both records carry their `39ab45a` bytes, make the edits listed in Consumer Closure and nothing else:
   - **register:** the freshness entry and row SPP-6;
   - **disposition record:** the freshness entry and the `subscription_payment_proofs` row's session, findings, SPP-6 evidence and Next.

   The two files must then hash to the prototype's: register `4794c75029a98025758d6ac6923891a220eeb40ce757a76339bb2747c0f9d195`, disposition `b355ab2b2c97ba5a069174249d7fcbc94eac2e822d704b2b7f7ebc9ff5011d70`. Otherwise stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, record it, running no command that `-Finish` runs:
   - **Byte identity.** The six files of Steps 1–3 equal their frozen SHA-256 values, so the Pre-Approval evidence is evidence about exactly these bytes: the clean reset, pgTAP A/B, the proof, smoke, the causal negative and M1–M6.
   - **The narrow check.** Tests 153, 152 and 47 alone (`npx supabase test db` on those three files) pass against the local stack.
   - **The four `scripts/test_*_guard.ps1` on the working tree,** where only the pre-deploy drift in Consumer Closure may fail their CONTROL cases.
   - **Scope.** `git status` shows changes only to Write Scope paths, and `git diff --check` is clean.
   - **A fresh Primary baseline, read-only:**
     - the project URL, the full ordered ledger and the absence of the target migration;
     - the function and structural surfaces;
     - the review's `prosrc` md5, security mode, owner, configuration, ACL and comment;
     - the tenant, subscription and payment-proof counts.

   Record the predicted delta.
5. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 4 and present the Gate-2 package. Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261010210000_a_payment_proof_is_decided_once`. If it is absent and deployment is separately authorized:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts and the function's md5.
   - On an exact match, prove the transmitted text's md5 server-side, then apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires:
     - exactly one new row;
     - its stored statement md5 equal to the file's;
     - no existing target version.
   - Read fresh:
     - the ledger, the function surface and all ten structural surfaces;
     - the function's definition, security mode, owner, configuration, ACL and comment;
     - the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with the HTTP clause unchanged.
   - Confirm that `supabase/tests` holds 153 files whose literal `plan(N)` values sum to 2815, then set `Suite **153 files / 2815 assertions**`. If either differs, stop.
   - Mark SPP-6 `DEPLOYED` with Cert `✅`, worded without a date beneath the register's freshness line.
   - Regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` (stored LF) with the canonical generators.
   - Run the four `scripts/test_*_guard.ps1` and require each to pass.
   - Set the Runtime Checkpoint to DONE.
   - Run `check_primary_ledger.ps1`, `check_database_parity_evidence.ps1`, repository consistency and `git diff --check`.

   If Primary is unproven, stop.
8. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`. Record the mode, status and step that run prints.
   - Independently Review the committed implementation against every Acceptance Criterion, under `## Verification Notes`. After `Verdict: Confirmed Complete`, do all of the following in the Complete commit:
     - transition to Complete and clear `Active Change Request`;
     - run `scripts/batch6_select_target.ps1` and record its Top-12;
     - set `Last Completed` to SPEC-261;
     - in `Current Module`, name SPEC-261 and SPP-6 where SPEC-260 and SPP-5 stand, with Batch 6 resuming at Slice 39;
     - set `Next capability` to **Foundation Completion Programme — Batch 6 Slice 39**, naming the measured first target, followed by the existing Phase-8 order, closed-chapter and standing-fact sentences unchanged;
     - keep the manifest within 7000 characters;
     - regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate with `scripts/publish_candidate.ps1` and require exact-SHA candidate CI.
   - Promote the same accepted SHA, require main CI, and run `-Certify` for `REMOTE_CERTIFY: READY`.
   - Verify synchronized clean refs.

## Acceptance Criteria

- [x] `app.platform_review_payment_proof` locks the proof it judges (`for no key update`) before its `pending` check. Of two concurrent reviews of one proof, the waiter is refused with the existing message, whatever either decides (H, I, J and L).
- [x] No race leaves a rejected proof behind an activation, an approved proof that was rejected, a second decision, a second activation or the second reviewer's terms. Each records one decision event and one security event, with a true from-state.
- [x] A rolled-back review releases its waiter to decide once (K). A failed activation rolls back its decision, and single approvals, rejections and refused replays behave as before (N).
- [x] An upload and a document link's key-share check are not made to wait by an open review (L). A review waiting on the lifecycle job's subscription completes without a deadlock (M).
- [x] The function keeps its signature, owner `postgres`, SECURITY DEFINER, `search_path=""`, ACL `{postgres=X/postgres,service_role=X/postgres}` and no comment. Its only code change is the lock clause.
- [x] `scripts/verify_subscription_concurrency.py` runs all fourteen cases plus fault isolation, each independently, and is named in Additional Verification. Test 153 runs in every CI database job. Tests 47, 131, 148 and 152 pass, and Test 152's assertions are unchanged.
- [x] Mutants M1–M6 are each killed, with installation and restoration proven, and the causal negative is recorded.
- [x] SPP-6 (Medium) is FIXED and DEPLOYED in the register. The `subscription_payment_proofs` row names SPEC-261 and SPP-6, carries the SPP-6 evidence and no longer says the race is unmeasured. It stays `AUDITED-OPEN` on SPP-3, coverage stays 39 of 78, and no other row of either record changed.
- [x] The migration, Tests 153 and 152, and the proof matched their frozen SHA-256 values when applied.
- [x] Primary, the recorded evidence, the manifest (249 migrations; 153 files / 2815 assertions; 464 HTTP assertions), the API contract and `ai-map.json` agree, and the four CI-only guard self-tests and repository consistency pass.
- [x] The manifest names Batch 6 Slice 39 and its measured target as the next capability, with no Active Change Request.
- [x] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [x] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-10-11 — Gate 1 approval and execution started

- **Authority:** the owner's one-time SPEC-261 completion authorization (2026-10-11). It approves Gate 1 for Draft `4d60253f06c63292ef62ddb31a9a73a6aa201517`, contract SHA-256 `4e798bb9a1f782b799bb63a3ad53b75dd178d9c809264c21531b830ae2d0895a`, migration `20261010210000`, SHA-256 `fa652cddd384989256ddbdef593486b51a7bb23739ae1639c5ab83a342a9ca1c`, MD5 `2539aa91d9bff705475fb465eaad33c4`, 4714 bytes, LF. The correction is limited to locking the proof row with `for no key update` before its status is judged. Verified before acting:
  - HEAD was the Draft commit, 1 ahead of and 0 behind `origin/main` `39ab45a`, and the working tree was clean;
  - the contract file and its committed blob both hash to the approved value;
  - the frozen prototype files in the scratch worktree `wt261` hash to their Step 1–3 values: migration `fa652cdd…` (MD5 `2539aa91…`, 4714 bytes), test 153 `679b869d…`, the proof `3c13a698…`, test 152 `ab72f990…`, register `4794c750…`, disposition record `b355ab2b…`;
  - Write Scope is the eleven paths above.

  Approval was committed at `e2dd2b3`; its pre-commit Gate returned `APPROVAL_EVIDENCE: PASS`.
- **Preconditions:** the migration and test 153 are absent. The proof script, test 152, the register, the disposition record, the API contract and the Primary evidence file are unchanged since `39ab45a`.
- **Publication range:** before this commit, `origin/main..HEAD` held 2 commits with 0 merges and was 0 behind.
- **Worktrees.** A read-only inventory; nothing was modified.
  - `wt251` is clean at `578f3fb`, and `owt/p2` is clean at `7fe62ed`.
  - `wt255` at `33e4db6` has 6 entries, and `C:\w234` at `6c48fbb` has 15.
  - `wt260` (4 entries, `e26733a`) and `wt261` (6 entries, `39ab45a`) hold only SPEC-260's and this contract's prototype bytes.

  All stay untouched.
- **Gate 2 stands before Step 6.** The same authorization grants an advance, one-time, exact-byte Gate 2 for this migration to Primary `vrvtsxexkiiiivlkdxzp` only. It takes effect only after Step 4's readiness requirements pass, and it is recorded at Step 5 only if they do. Secondary is never contacted.

### 2026-10-11 — Steps 1–3 applied; pre-deploy readiness gate

- **Steps 1–3.** The migration, test 153 and the proof were absent or carried their `39ab45a` bytes. They were written byte-for-byte from the frozen prototype. Test 152, the register and the disposition record received exactly Consumer Closure's edits (the prototype's anchored-edit script, each anchor matching once). All six files hash to their frozen values:
  - migration `fa652cddd384989256ddbdef593486b51a7bb23739ae1639c5ab83a342a9ca1c`, MD5 `2539aa91d9bff705475fb465eaad33c4`, 4714 bytes;
  - test 153 `679b869d…`; the proof `3c13a698…`; test 152 `ab72f990…`;
  - register `4794c750…`; disposition record `b355ab2b…`.

  Each is LF with no CR or other control byte.
- **Byte identity.** Those six files are the bytes the Pre-Approval evidence measured. That evidence is carried by identity, not re-run: the clean reset, pgTAP A/B 153 / 2815, the proof 15/0, smoke, the causal negative (`11 passed, 4 failed`) and M1–M6.
- **The narrow check.** The pending migration was applied to the local stack with `npx supabase migration up`: ledger 249, latest `20261010210000`. `npx supabase test db` on tests 153, 152 and 47 alone: `Files=3, Tests=40`, `Result: PASS`.
  - The function reads `prosrc` MD5 `2cbc94867ea6ce5dc81cf5cd98511b25`, SECURITY DEFINER, owner `postgres`, `search_path=""`, ACL `{postgres=X/postgres,service_role=X/postgres}`, no comment, and the same identity arguments and `void` result.
  - `parity_surface.sql` locally: functions `724baac791a6a79c7d4328835d800f50`/323, combined `5a9ed7ff90852acec9a128b7fe4f8c5a`/3115. The other nine surfaces each equal the recorded Primary value. Ledger 249 `323eae75c4a400b4cc6f13317ec21611`.
- **The four CI-only guard self-tests, on this working tree:** the four run with Steps 1–3 applied:
  - `test_future_date_guard` passed 18/0 (exit 0, 3.0 min);
  - `test_status_contradiction_guard` passed 33/0 (exit 0, 2.9 min);
  - `test_primary_ledger_guard` failed only its two CONTROL cases, 11/2 (0.2 min);
  - `test_cold_start_state_guard` failed only its nine CONTROL, second-direction CONTROL and restore cases (CONTROL; A2, C2 and E CONTROL; A-, B-, C- and D-restore; second direction), 25/9 (3.7 min).

  Each failing case requires an untouched copy of the repository to be CLEAN, which the drift below prevents until Step 7. Every mutation case passed. This is the same pattern as SPEC-260's Step 4. Step 7's run, where each must pass, stays mandatory.
- **Scope.** `git status` shows exactly the six Step 1–3 paths, all in Write Scope, and the stash is empty. `git diff --check` exit 0.
- **Repository consistency:** `REPOSITORY CONSISTENCY: 6 issue(s)`. This is exactly the pre-deploy drift that Consumer Closure lists:
  - 248 vs 249 migrations;
  - latest `20261010160000` vs `20261010210000`;
  - fingerprint `207f3fad…` vs `323eae75…`;
  - 152 vs 153 files, and 2810 vs 2815 assertions;
  - RECOVER-1 ledger evidence.

  The counter counts RECOVER-1 once; Consumer Closure's "7" counted its two internal issues separately. Checks 21–28 are clean.
- **Fresh Primary baseline, read-only (`vrvtsxexkiiiivlkdxzp`, URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`):**
  - ledger 248 `207f3fad1a5d2a5b7d640f598c2050e9`, latest `20261010160000`; no row for the target version or name, and none after `20261010160000`;
  - functions (Check L2/P2) `b3d4fc61413a43ef1ea60bc27a323b6e`/323;
  - `parity_surface.sql`'s ten surfaces equal the recorded evidence, combined `c93fb668bb243fa19274bed2605889ab`/3115;
  - `app.platform_review_payment_proof`: `prosrc` MD5 `8d81c756333a8f13e2d5715111310a64`, definition MD5 `9c8f1a3dcc08160206cad2f626d4b16f`. It is SECURITY DEFINER, owner `postgres`, `search_path=""`, ACL `{postgres=X/postgres,service_role=X/postgres}`, with no comment and the same identity arguments as locally;
  - `subscription_payment_proofs`: RLS on (not forced), 3 policies, and three triggers all enabled (`derive_reviewer`, `derive_uploader`, `enforce_catalog_codes`). Grants: `authenticated` INSERT, SELECT and UPDATE; `service_role` DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE and UPDATE;
  - 0 tenants, 0 subscriptions, 0 payment proofs.
- **Predicted delta on Primary:**
  - ledger 249 / `323eae75c4a400b4cc6f13317ec21611`, latest `20261010210000`;
  - functions `724baac791a6a79c7d4328835d800f50`/323, combined `5a9ed7ff90852acec9a128b7fe4f8c5a`/3115;
  - the review's `prosrc` becoming the transmitted text, MD5 `2cbc94867ea6ce5dc81cf5cd98511b25`, as locally.

  Its security mode, owner, configuration, ACL and comment, and the table's triggers, policies, RLS and grants, are unchanged. No other surface moves, and no business row is written.

### 2026-10-11 — Human Gate 2: owner authorization

- **Authority:** the owner's one-time SPEC-261 completion authorization of 2026-10-11, §3. It grants an advance, one-time, exact-byte Gate 2 for exactly the migration `supabase/migrations/20261010210000_a_payment_proof_is_decided_once.sql`: SHA-256 `fa652cddd384989256ddbdef593486b51a7bb23739ae1639c5ab83a342a9ca1c`, MD5 `2539aa91d9bff705475fb465eaad33c4`, 4714 bytes, LF. It covers Primary `vrvtsxexkiiiivlkdxzp` only, by the approved procedure.
- **Its condition:** it takes effect only after every Gate 2 readiness requirement has passed. The pre-deploy readiness gate above records each requirement the authorization names:
  - the frozen bytes and both hashes;
  - the local readiness and adversarial evidence;
  - the current Primary ledger and the target's absence;
  - the function's definition, owner, privileges, security mode and `search_path`, and the structural surfaces;
  - local-to-Primary baseline agreement and the exact predicted delta;
  - zero business rows;
  - an unchanged Write Scope.

  Each held. No lifecycle rule requires an owner decision made after readiness: Step 5 requires exact owner authorization for the migration SHA-256 to be recorded in this log, and it now is.
- **Not authorized:** any other migration or Primary change, SPP-3, Slice 39, another Change Request, or any change to ORVION's approval policy. Secondary `brplkqmbzffpxqgkkdzo` is never contacted.

### 2026-10-11 — Step 6: Primary deployment

- **Local recheck, immediately before the write:**
  - HEAD `257f246ecb4add0a9f1fc1c15f3326bcbac5bd96` on the chain `4d60253 → e2dd2b3 → 2d79f77 → 257f246`, 0 behind `origin/main` `39ab45a`;
  - Draft `4d60253`'s contract hashes to `4e798bb9…`, and since then this contract changed only its status lines and its Execution Log;
  - the six Step 1–3 files hash to their frozen values after the stash round trip: migration `fa652cdd…` (MD5 `2539aa91…`, 4714 bytes, 94 LF, 0 CR), test 153 `679b869d…`, the proof `3c13a698…`, test 152 `ab72f990…`, register `4794c750…` and disposition record `b355ab2b…`;
  - the working tree touches only Write Scope paths, and the stash is empty.
- **Primary recheck, read-only:**
  - ledger 248 `207f3fad1a5d2a5b7d640f598c2050e9`, latest `20261010160000`, the target absent by version and name, no row after it;
  - functions `b3d4fc61…`/323;
  - the review function: prosrc `8d81c756333a8f13e2d5715111310a64`, definition `9c8f1a3dcc08160206cad2f626d4b16f`, SECURITY DEFINER, owner `postgres`, ACL `{postgres=X/postgres,service_role=X/postgres}`, `search_path=""`, no comment;
  - 0 tenants, subscriptions and payment proofs.
- **Server-side proof:** the transmitted text hashed on Primary to MD5 `2539aa91d9bff705475fb465eaad33c4`, 4714 bytes, 94 LF, 0 CR.
- **Apply:** that same text, through the Primary connector's `apply_migration`, returned success. A fresh read showed one new row, temporary version `20261010230810`, with one stored statement (MD5 `2539aa91…`, 4714 bytes), and 249 rows in all. The other 248 still hashed to `207f3fad…`.
- **Reconciliation:** one guarded UPDATE renamed only that row to `20261010210000`, and it renamed 1 row. Every guard held:
  - 249 rows;
  - exactly one row after `20261010160000`;
  - the other 248 hashing to `207f3fad…`;
  - one stored statement, its MD5 equal to the file's;
  - no existing target.
- **Fresh post-write reads (`2026-10-10T23:08:49Z`):**
  - ledger 249 `323eae75c4a400b4cc6f13317ec21611`, latest `20261010210000`, exactly one row for the migration, the temporary version gone;
  - functions `724baac791a6a79c7d4328835d800f50`/323 (both Check L2/P2 and `parity_surface.sql`). Triggers `a46035c1…`/309, policies `b67d466a…`/125, constraints `cea733ef…`/525, grants `6727f6d8…`/189, columns `448db887…`/1134, views `10bb212a…`/16, indexes `22a4d58c…`/300, status transitions `db2165c7…`/115 and RLS `c117cbf7…`/79 are unchanged. Combined `5a9ed7ff90852acec9a128b7fe4f8c5a`/3115. Each equals the prediction;
  - the function: prosrc `2cbc94867ea6ce5dc81cf5cd98511b25` and definition `9d58dec566dd66fb9f07bd0c35c456d1`, each equal to local. SECURITY DEFINER, owner `postgres`, ACL `{postgres=X/postgres,service_role=X/postgres}`, `search_path=""`, no comment, and the same identity arguments and `void` result;
  - the table: RLS on (not forced), 3 policies, the same three enabled triggers and unchanged grants;
  - 0 tenants, subscriptions and payment proofs. No business-data write.
- **Secondary** `brplkqmbzffpxqgkkdzo` was not contacted.

### 2026-10-11 — Step 7: evidence and measured state

- **The evidence file, `reports/evidence/primary-ledger-evidence.json`,** was written from the fresh post-write readings only:
  - `read_at` `2026-10-10T23:08:49Z`;
  - `repository_head` `257f246e…`;
  - 249 migrations, `323eae75…`;
  - functions `724baac7…`/323, structural `5a9ed7ff…`/3115;
  - the ledger list appends `20261010210000_a_payment_proof_is_decided_once`.

  `check_primary_ledger.ps1` recomputes 249 / `323eae75…` from the file and finds it equal to the repository's migration files.
- **Manifest:** `Live state` reads 249 migrations, latest `20261010210000`, and the new ledger, function and structural hashes. Its dates stay 2026-10-10, the UTC date of the Primary reading. It reads `Suite **153 files / 2815 assertions**`, with the HTTP clause unchanged (464, last passed 2026-10-10). `supabase/tests` holds 153 files whose literal `plan(N)` values sum to 2815.
- **Register:** SPP-6 reads `DEPLOYED to Primary under separate exact-byte owner authorization`, with Cert `✅`, worded without a new date.
- **Generated artifacts:** `MASTER_API_CONTRACT.md` regenerates unchanged (`d28fb567…`; 80 RPC endpoints, 8 views, 74 tables). `ai-map.json` is regenerated and stored LF; only `generated_at` changed.
- **CI-only guard self-tests, on this deployed state:** each passed, exit 0: `test_future_date_guard` 18/0, `test_status_contradiction_guard` 33/0, `test_primary_ledger_guard` 13/0 and `test_cold_start_state_guard` 34/0 (2.8, 2.7, 0.3 and 3.7 min). The CONTROL and restore cases that the pre-deploy drift failed at Step 4 now pass.
- **Runtime Checkpoint** is `DONE`.
- **Checks:**
  - `check_primary_ledger.ps1`: RECOVER-1 `CLEAN`;
  - `check_database_parity_evidence.ps1`: `DATABASE PARITY: CLEAN` and `PRIMARY PARITY EVIDENCE: CLEAN`;
  - repository consistency: `CLEAN`;
  - `git diff --check`: exit 0.


### 2026-10-11 — Post-deploy local certification

Canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` ran on the clean, committed HEAD `a4ba775` with nothing else running. It ran in VERIFY mode (`STATUS: In Progress`, `STEP: DONE`), with profiles DATABASE and REPOSITORY plus the declared `python scripts/verify_subscription_concurrency.py`. It reported `LOCAL_CERTIFY: READY` in 4.2 min, and every mandatory verification passed in that run:
- reset; pgTAP Pass A; the two-session proof; pgTAP Pass B; smoke;
- `check_database_parity_evidence.ps1`, repository consistency, `git diff --check` and `check_primary_ledger.ps1`.

The four CI-only guard self-tests passed earlier on the same committed content (Step 7). The causal negative and M1–M6 were recorded before approval on the same migration, test and proof bytes, which are unchanged, so they were not repeated. Test 153's assertions are checked by both pgTAP passes.

**Selector after SPEC-261** (`scripts/batch6_select_target.ps1`, 39 surfaces still `NOT-RECORDED`), as Exposure/coverage:
1. `complaints` 8/48
2. `payment_allocations` 8/60
3. `receipts` 7/20
4. `chart_of_accounts` 7/38
5. `notification_deliveries` 7/42
6. `approval_requests` 7/52
7. `user_branch_assignments` 7/572
8. `departments` 7/636
9. `user_role_assignments` 7/636
10. `customer_consents` 6/18
11. `document_retention_policies` 6/36
12. `document_links` 6/54

The ranking is unchanged from SPEC-260. Slice 39's measured target is `complaints`.
## Verification Notes

### 2026-10-11 — Independent Review of the execution commit `a4ba775`

Reviewed the committed tree against the approved Draft `4d60253`, the owner's Gate-2 authorization and the eleven-path Write Scope. The review read the implementation and the live state, not the Execution Log.

1. **The lock (criterion 1).** The committed migration's one statement replaces `app.platform_review_payment_proof`.
   - Comment-stripped and whitespace-normalized, its body equals the only earlier definition (`202607054500`) with ` for no key update` added to the proof read, and with no other difference.
   - The lock precedes the `pending` check, which keeps its 23514 message.
   - Test 153 pins this (assertions 1–3), and both `-Finish` pgTAP passes ran it.
   - The two-session proof passed inside `-Finish`. In H, I, J and L the waiter is observed blocked and then refused "already approved" or "already rejected".
2. **No double decision (criterion 2).** The proof's `decided()` reads the proof status, the subscription state and terms, the decision and activation events with their from-states, and the security decisions. H and J assert `approved | active/annual | subscription_payment_approved:pending->approved,subscription_activated:grace_period->active | approved`. I asserts `rejected | grace_period/- | subscription_payment_rejected:pending->rejected | rejected`. Each records one decision event, one security event, a true from-state, and at most one activation, on the first reviewer's terms.
3. **Error behaviour and single reviews (criterion 3).**
   - K: a rolled-back review's waiter decides once.
   - N: a failed activation (`unknown or inactive plan_code`) leaves `pending | grace_period/- | - | -`; a single approval activates once; a single rejection leaves the subscription untouched; and both replays are refused.
4. **No new waiting, no deadlock (criterion 4).**
   - L: an upload and a proof key-share check finish under `lock_timeout` while a review is open, and a second review is refused.
   - M: a review waiting on the lifecycle job's subscription completes as `approved | active/annual`.
5. **Function properties (criterion 5).** Primary and the certified local stack read the same `prosrc` `2cbc94867ea6ce5dc81cf5cd98511b25` and definition `9d58dec566dd66fb9f07bd0c35c456d1`. The function is SECURITY DEFINER, owner `postgres`, `search_path=""`, ACL `{postgres=X/postgres,service_role=X/postgres}`, with no comment and the same identity arguments and `void` result. Test 153 assertion 5 pins the security mode, path and grants.
6. **Harness and tests (criterion 6).**
   - The proof defines the seven SPEC-250 cases and H–N, each with its own tenant, plus fault isolation. It is named in Additional Verification and passed in `-Finish`.
   - Tests 47, 131, 148 and 152 passed in both full passes.
   - Test 152's diff against `39ab45a` is lines 11–13 of its CONCURRENCY comment only.
7. **Mutation (criterion 7).** M1–M6 and the causal negative (`11 passed, 4 failed`; test 153 failing 1 and 2) were recorded in Pre-Approval Evidence on the frozen bytes. The committed migration, test 153 and proof blobs hash to those bytes.
8. **Records (criterion 8).**
   - **Register:** SPP-6 reads Medium, FIXED and DEPLOYED, with Cert `✅`. Against `39ab45a`, the register changed only its freshness entry and that row.
   - **Disposition:** the `subscription_payment_proofs` row names `SPEC-261-a-payment-proof-is-decided-once` and `SPP-5, SPP-6, SPP-3, FX-4`, and carries the SPP-6 evidence. Its Next is SPP-3's trigger, and it stays `AUDITED-OPEN` / `ADVERSARIAL`.
   - The only remaining "not measured" in the disposition record is the freshness entry recording the correction. Against `39ab45a`, the record changed only the freshness entry and that row. The per-state counts are unchanged, and coverage reads 39 of 78.
9. **Frozen values (criterion 9).** The committed blobs hash to the approved values:
   - migration `fa652cddd384989256ddbdef593486b51a7bb23739ae1639c5ab83a342a9ca1c` (MD5 `2539aa91d9bff705475fb465eaad33c4`, 4714 bytes);
   - test 153 `679b869d…`;
   - test 152 `ab72f990…`;
   - the proof `3c13a698…`.

   Primary's stored statement MD5 is `2539aa91…`.
10. **Agreement (criterion 10).** Primary, the evidence and the manifest agree:
    - 249 migrations, `323eae75…`;
    - functions `724baac7…`/323, structural `5a9ed7ff…`/3115;
    - 153 files / 2815 assertions (plan sum recounted), 464 HTTP assertions.

    The API contract matches its generator (`d28fb567…`), and `ai-map.json` is LF. The four guard self-tests passed on the deployed content, and repository consistency and `-Finish`'s parity and ledger checks pass.
11. **Next capability (criterion 11).** The Complete commit keeps Batch 6 Slice 39 and `complaints` (8/48), which the selector re-measured, and clears the Active Change Request.
12. **Primary and Secondary (criterion 12).**
    - Primary's ledger holds exactly one row for the migration, after one guarded rename of temporary version `20261010230810`.
    - It holds 0 tenants, subscriptions and payment proofs before and after.
    - No other surface moved.
    - Secondary was never contacted.
13. **Scope (criterion 13).** `39ab45a..HEAD` changes ten paths, all in Write Scope. `MASTER_API_CONTRACT.md` regenerates unchanged.

**Outside this contract, and not a defect in it:**
- SPP-3, the platform decision recording no reviewer, stays owed on its trigger.
- Two approvals of two different proofs each activate the subscription, as in sequence. This is held as activation semantics.
- The certified local stack keeps the proof's committed fixture tenants until the next reset; this is local only.

Verdict: Confirmed Complete

## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created or deleted.
- [x] No section was added, removed or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

- **LEARN BEFORE GUESSING.** The race was re-measured from its mechanism, not its earlier report. The earlier observation that B "waited on a Lock" was B waiting at its UPDATE, after it had already judged. Re-measurement found a third, sharper race (I: a rejection turned into a paid approval). The writer population, the foreign keys and every explicit lock were read from the catalog and migrations before the lock order was claimed.
- **EARN IT.** Each race was reproduced with an observed blocking edge, closed by the repair and reopened by its mutants. The one alternative worth weighing was prototyped and measured, not argued.
- **WORTH IT.** A rejected payment can become paid access, and one payment can be decided twice on different terms, before the first production subscription.
- **SIMPLIFY IT WITHOUT WEAKENING.** One lock clause, the existing check and message, and the existing harness extended. There is no new script, trigger or mechanism. The pre-deploy step proves byte identity instead of re-running what `-Finish` runs.
- **A defect found in this contract's own evidence, not in the repair.** The first version of the new cases left `read_only` tenants owning a document, which turned Pass B red through tests 49, 52 and 60. Because `-Finish` runs Pass B after the declared proof, it would have failed certification. It was caught here by running `-Finish`'s order on the prototype.
- **Deliberately not changed:** SPP-3 and any platform reviewer identity; the upload; activation semantics, including two approvals of two proofs; Batch 6 coverage and the selector's ranking; n8n and Phase 8; the registered worktrees `wt251`, `wt255`, `wt260`, `owt/p2` and `C:\w234`.
