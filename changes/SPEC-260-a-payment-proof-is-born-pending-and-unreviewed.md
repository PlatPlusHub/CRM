# Change Request — SPEC-260

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Foundation Completion Programme Batch 6 Slice 38: give `public.subscription_payment_proofs` a truthful disposition and close **SPP-5**.

The surface is canon 31's `subscription_payment_proofs`: a tenant's bank-transfer proof for a subscription renewal, which the Platform Owner reviews. `authenticated` holds table-level INSERT, SELECT and UPDATE, and `app.upload_subscription_payment_proof` is SECURITY INVOKER through that same grant, so PostgREST serves the table beside it.

After this change one invariant holds on both doors and for every caller: **a payment proof is born `pending` and unreviewed, with no reviewer, and only `app.platform_review_payment_proof` decides it.**

Record the surface `AUDITED-OPEN`, because SPP-3 (the platform reviewer's identity) stays owed on its own trigger.

This contract does not touch any grant, policy, constraint, permission charge, state transition, canon document, other surface, n8n or any Phase-8 work.

## Business Reason

### Selection
`scripts/batch6_select_target.ps1`, run at `e26733a`, lists 40 surfaces still `NOT-RECORDED`. `subscription_payment_proofs` and `complaints` tie on both of its sort keys: Exposure 8 and coverage 48 (Score -40 each).
- The order inside the tie is not a measurement. The catalog query returns rows in `relname` order, with `complaints` first, and the printed order reverses it, so `Sort-Object` did not preserve its input on equal keys.
- The tie was broken on the control shape read from the catalog.
  - `complaints` carries seven triggers: a capability guard, the status-transition machine with 9 recorded transitions, the subscription write gate, archive authority, catalog codes, `created_by` derivation and `updated_at`.
  - `subscription_payment_proofs` carries three: catalog codes and two attribution derivations. It has no state or entry rule, holds a direct INSERT and UPDATE grant, and sits where a payment proof leads to paid access.

### Authority
- **Canon 28 (Subscription permissions, Notes):** "Subscription proof review is platform owner action. Tenant users may upload proof but cannot approve their own subscription renewal." REVIEW_SUBSCRIPTION_PAYMENT is held by no role, and SPEC-227 (`20260927120000`, SUB-3) refuses granting it.
- **Canon 31:** `reviewed_by nullable`, `reviewed_at nullable`.
- **The sole sanctioned writer, `app.upload_subscription_payment_proof`** (WP-04-B, `202607054500`): it charges MANAGE_TENANT_SETTINGS and writes `pending` with no review time. **The sole decider, `app.platform_review_payment_proof`:** session-less and SECURITY DEFINER, it decides only a `pending` proof and does not fill `reviewed_by`, which cannot name a platform operator (SPP-3).
- **FX-4** (`202607058900`) added `app.derive_proof_reviewer` so that the reviewer is derived, never accepted, and so that `83_…` assertion 22 holds with no exemption list.

### SPP-5 (Medium) — a payment proof was born already reviewed
Measured at `e26733a` on the local stack in rolled-back transactions, by a tenant `owner` holding MANAGE_TENANT_SETTINGS, on a lapsed tenant:
- **The upload named its uploader as reviewer.** The RPC's own proof was born `pending` with `reviewed_by` set to the owner who uploaded it. FX-4's trigger copied `app.derive_created_by` and stamps the session user on INSERT. The platform's session-less approval then left that name in place, so every approved proof recorded the tenant as its reviewer. FX-4 and SPP-3 record the column as NULL after every review, and on this path it never was.
- **The table door admitted a decided proof.** A direct INSERT created a proof born `approved`, uploaded 40 days earlier and reviewed 39 days earlier, with review notes "transfer confirmed by platform". Another was born `rejected`. Neither passed through the platform review, which then refuses either as already decided.
- **Held:** the owner's UPDATE to `approved` changed 0 rows (no role holds REVIEW_SUBSCRIPTION_PAYMENT), and DELETE has no grant.

Canon 28 forbids exactly what the record then said: the tenant decided its own renewal proof, on every proof through the sanctioned door. A tenant could also file a platform decision the platform never made. Medium, as ENTRY-1's born-decided rows are. It stays below SPP-2's High: only the holders of MANAGE_TENANT_SETTINGS, who upload proofs anyway, reach the door, and nothing reads a proof's status to grant access. Read-only on Primary `vrvtsxexkiiiivlkdxzp`: 0 proofs, so no stored row carries the false name.

It is ENTRY-1's class on a table outside ENTRY-1's list, which names only tables with a transition machine. ENTRY-1's row and count are unchanged.

### The repair
One migration replaces the body of `app.derive_proof_reviewer()`. That function is already the row-level BEFORE INSERT OR UPDATE trigger `subscription_payment_proofs_derive_reviewer`: SECURITY INVOKER, `search_path=""`, owner `postgres`, ACL `{postgres=X/postgres}`.
- **On INSERT, for every caller:** a `status_code` other than `pending`, or any `reviewed_at`, is refused (23514, "a payment proof is created pending and unreviewed; only app.platform_review_payment_proof decides it"), and `reviewed_by` is derived as NULL.
- **On UPDATE:** unchanged. A session-less write keeps its values, and a signed-in one stamps the reviewer once.

No table, column, grant, policy, constraint, trigger, permission, event type, catalog value or state transition is added or changed. `app.upload_subscription_payment_proof` and `app.platform_review_payment_proof` are unchanged.

### Rejected
- **A policy WITH CHECK arm (`status_code = 'pending'`):** it binds only RLS-subject callers, answers with RLS's generic message, and re-transcribes a policy that test 50 pins. It also leaves the reviewer stamp, which a policy cannot repair.
- **A second trigger for the birth rule:** the reviewer trigger already fires on INSERT for every caller and already owns the review columns.
- **Silently setting `pending`:** a forged decision would be quietly turned into a pending proof. Refusing names the conflict, as SPEC-257 chose for ENTRY-1.
- **Refusing a stated `reviewed_by`:** an actor column is derived, never accepted (FX-3, FX-4). The stated value is discarded, as `uploaded_by`'s already is.
- **Dropping the reviewer trigger:** `83_…` assertion 22 requires a BEFORE trigger deriving every actor column, with no exemption list, and FX-4's reason for the UPDATE arm stands.
- **Revoking INSERT and making the upload RPC SECURITY DEFINER:** that is a larger change and adds a definer door, which defends nothing this repair does not.
- **Locking the proof in `app.platform_review_payment_proof`:** see Held.

### Held, recorded so a later slice does not rediscover it
- **Authority:** an `employee` without MANAGE_TENANT_SETTINGS is refused 42501 (`47_…` 19). REVIEW_SUBSCRIPTION_PAYMENT cannot be granted (`131_…`), and the owner's UPDATE is pinned by test 152 assertion 10.
- **Tenant:** a proof under another tenant is refused by RLS (assertion 9). The foreign keys are tenant-qualified.
- **Replay:** a second review of a decided proof is refused (`47_…` 16).
- **Observability:** a direct pending proof emits no upload event and no document link. It can only delay its own uploader's renewal, because the platform reviews a proof by its id.
- **`uploaded_at`:** writable at the table door like every `created_at`, and read by no function, view or policy.
- **Document:** a direct proof may name any document of its own tenant, which the owner can already read and upload.
- **`review_notes`:** the upload stores its note in `review_notes`, and the platform's review keeps it unless it writes its own. That is the RPC's design, and no reader is misled about who decided.
- **Write gate:** the table has no subscription write gate, by design, because a lapsed tenant must pay its way back (`35_…`).
- **Concurrency, read from the code and not measured:** `app.platform_review_payment_proof` reads the proof without a lock, so two concurrent reviews could each pass the `pending` check. Only `postgres` and `service_role` can execute it, and there is one platform operator. The disposition row routes it to SPP-3's trigger (a second platform operator or a platform console), where the reviewer's identity is also owed.

## Risks

- **Changed INSERT semantics, for every caller.** A proof inserted with a status other than `pending`, or with a review time, is refused 23514, and a stated `reviewed_by` is discarded.
  - Every pgTAP fixture that writes a proof directly writes `pending` with no review time (tests 35, 47 and 62).
  - The only HTTP producer is the RPC (`verify_journey_branches.ps1`).
  - The whole suite passes unchanged on the prototype.
  - A future historical import of decided proofs would have to insert `pending` and then review, which no path does today.
- **Mechanism substitution.** A proof inserted with an unknown status code now meets this guard's 23514 before `app.enforce_catalog_codes`, because the triggers fire in name order. No test inserts an unknown status.
- **Primary deployment** replaces one function body and nothing else. It requires separate exact-byte owner authorization (Gate 2); approving this contract does not authorize it. Primary holds no proofs.
- **Workstation, not in scope:** resets for this contract run from the main checkout. A reset from a scratch git worktree leaves local storage without `bucketid_objname`.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-260-a-payment-proof-is-born-pending-and-unreviewed.md`
- `supabase/migrations/20261010160000_a_payment_proof_is_born_pending_and_unreviewed.sql`
- `supabase/tests/152_a_payment_proof_is_born_pending_and_unreviewed_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607054000_subscription_lifecycle_and_platform_authority.sql`
- `supabase/migrations/202607054500_subscription_payment_proof_lifecycle.sql`
- `supabase/migrations/202607054800_subscription_payment_proof_scope.sql`
- `supabase/migrations/202607056500_action_attributions_are_derived.sql`
- `supabase/migrations/202607058900_who_did_this_is_derived_never_accepted.sql`
- `supabase/migrations/20260927120000_platform_authority_cannot_be_granted.sql`
- `supabase/tests/35_subscription_write_gate_test.sql`
- `supabase/tests/47_payment_proof_lifecycle_test.sql`
- `supabase/tests/48_document_storage_test.sql`
- `supabase/tests/50_policy_role_scope_test.sql`
- `supabase/tests/62_action_attribution_test.sql`
- `supabase/tests/80_subscription_licensing_test.sql`
- `supabase/tests/83_actor_attribution_test.sql`
- `supabase/tests/88_parent_state_on_every_door_test.sql`
- `supabase/tests/89_finance_periphery_parent_state_test.sql`
- `supabase/tests/106_otp_challenge_subject_authority_test.sql`
- `supabase/tests/131_platform_authority_cannot_be_granted_test.sql`
- `reports/architecture-decision-records.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/09_saas_plans_and_access.md`
- `_ORVION_CANONICAL/26_state_machines.md`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `_ORVION_CANONICAL/31_schema_draft.md`
- `scripts/verify_database.sql`
- `scripts/verify_api_end_to_end.ps1`
- `scripts/verify_care_journeys.ps1`
- `scripts/verify_journey_branches.ps1`
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
- `_ORVION_CANONICAL/28_permissions_matrix.md` (Subscription permissions and Notes); `_ORVION_CANONICAL/31_schema_draft.md` (`subscription_payment_proofs`); `_ORVION_CANONICAL/09_saas_plans_and_access.md`
- `reports/master/MASTER_GAP_REGISTER.md` (SPP-1/SPP-2, SPP-3, FX-4, PP-4, DOC-6, SUB-3, ENTRY-1, PAR-4); `reports/master/MASTER_SURFACE_DISPOSITION.md`; `reports/master/MASTER_EXECUTION_PLAN.md` Batch 6 method and EC-1…EC-11
- `supabase/migrations/202607054500_subscription_payment_proof_lifecycle.sql`; `supabase/migrations/202607058900_who_did_this_is_derived_never_accepted.sql`; `supabase/migrations/20260927120000_platform_authority_cannot_be_granted.sql`
- Current local `app.upload_subscription_payment_proof`, `app.platform_review_payment_proof`, `app.derive_proof_reviewer`, `app.derive_proof_uploader`, and the table's grants, policies and triggers
- Tests 35, 47, 62, 83 and 131

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
| A proof is born `pending`, with no review time, for every caller | `app.upload_subscription_payment_proof`; `app.platform_review_payment_proof`; the table's INSERT door | WRITE | The prototype is a scratch worktree at `e26733a`, with the migration applied with its ledger row on a stack reset from the main checkout. Migration SHA-256 `cadb6f05e9c4f642b8b27fe6f93c91ae098eb674667eef84c47f2deba506c012`, md5 `f417ebb93516cb2c82f2b8e34da654cc`, 3208 bytes, 54 LF lines, ASCII. A proof born `approved` (backdated, with forged review notes), born `rejected`, or `pending` with a review time was refused 23514, signed in and session-less. The RPC's upload and a direct `pending` proof were accepted. |
| The reviewer is NULL at birth | `reviewed_by`; FX-4; SPP-3; `83_…` assertion 22 | WRITE | The RPC's proof and a direct proof stating the employee as reviewer each read no reviewer. After the platform's approval the proof reads `approved`, with no reviewer and a review time, and the subscription `active`. The function still assigns `new.reviewed_by`, so test 83 passes 23/23. |
| The UPDATE door and the platform review | `scope_update`; SUB-3; the session-less arm | VERIFY | Unchanged: the owner's UPDATE to `approved` changes nothing; the platform review approves and reactivates (test 152 assertions 10, 12 and 13; test 47 19/19; test 131 31/31). |
| Tests naming this table or its RPCs | tests 35, 47, 48, 50, 62, 80, 83, 88, 89, 106, 131 | VERIFY | On the final bytes each passes unchanged: 27/27, 19/19, 12/12, 5/5, 9/9, 19/19, 23/23, 25/25, 21/21, 16/16, 31/31. |
| Test 152 | `supabase/tests` | WRITE | SHA-256 `8bed225bc146d843695512a11621fb2d0380cc0308271b179a222c1eaa55dd5f`, `plan(16)`, 12369 bytes, 195 LF lines, ASCII: 16/16 on the prototype. With FX-4's pre-repair function installed inside its own transaction, it fails assertions 3, 4, 5, 6, 8, 11, 13, 14 and 16. |
| The generated API contract | `MASTER_API_CONTRACT.md` | WRITE | The canonical generator against the prototype is byte-identical to the committed contract (`d28fb5672ca9c0795a99a74746069c973e1392edcc5e3d2a5a315348138175fd`): 80 RPC endpoints (80 with HTTP evidence), 8 views and 74 tables. Step 7 regenerates it, and it stays unchanged. |
| Suite, HTTP and smoke | full pgTAP; the six HTTP suites; `scripts/verify_database.sql` | VERIFY | On the prototype, in `-Finish`'s order on a main-checkout reset: pgTAP Pass A `Files=152, Tests=2810` PASS; HTTP 35 + 40 + 85 + 122 + 122 + 60 = 464 passed, 0 failed; Pass B 152 / 2810 PASS; smoke `ALL CHECKS PASSED (78 tables, … 71/622 catalog, …)`; plan sum 152 / 2810. That run carried a migration and test 152 differing from the final bytes only in comment lines, so the function's `prosrc` was identical. Test 152, the focused tests, the causal negative and M1–M4 were rerun on the final bytes. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | With the migration, the function surface becomes `b3d4fc61413a43ef1ea60bc27a323b6e`/323 and the combined surface `c93fb668bb243fa19274bed2605889ab`/3115. The other nine surfaces each equal the recorded Primary value. The 248-file ledger fingerprint is `207f3fad1a5d2a5b7d640f598c2050e9`. `app.derive_proof_reviewer`'s `prosrc` md5 moves from `037078ce190d9980d8429f74ec63545c` (read on Primary 2026-10-10) to `b3cda129c52b83db7739125b93c3e112`. It stays SECURITY INVOKER, owner `postgres`, `search_path=""`, ACL `{postgres=X/postgres}`. |
| Measured state that moves | manifest (`Live state`, suite figure, coverage, Last Completed, Current Module, Next capability); `primary-ledger-evidence.json`; `ai-map.json` | WRITE | 247 → 248 migrations, latest `20261010160000`; 151 → 152 files and 2794 → 2810 assertions; coverage 38 → 39 of 78. HTTP (464), tables (78), catalog (71/622), views (8) and client RPCs (80) do not move. Primary values are written only from fresh post-deploy readings. |
| SPP-5 fixed; FX-4 and SPP-3 corrected; the surface `AUDITED-OPEN` | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 2, 21, 22, 24, 25 | WRITE | Test 152's `-- ATTACK-CLASSES:` line and negative assertions satisfy Check 24. SPP-5's Owner field is `—`, so Check 25 reads no owner decision. The coverage line becomes 16 `AUDITED`, 20 `AUDITED-OPEN` and 39 `NOT-RECORDED`. On the prototype the record edits produce register SHA-256 `b5bbeb2b5a6b0aabc9d54cd28d8e5621041aeb55031caabae3c3688a5a92af27` and disposition SHA-256 `5201e33682f5b236ecbdc0625a7b5755e78459d062871d5b36cd5dca5f0648d4`. |
| Repository consistency | `scripts/check_repository_consistency.ps1` | VERIFY | On the prototype, exactly the pre-deploy measured-state drift: `manifest says 247 migrations, repository holds 248`; latest `20261010140000` vs `20261010160000`; ledger fingerprint `f2fd1294…` vs `207f3fad…`; `151 test files` vs 152; `2794 assertions` vs 2810; RECOVER-1 ledger evidence (2). Checks 21 to 28 are clean, and `git diff --check` is clean. These are not waived: Step 7 makes them true, and Step 8 requires them green. |
| CI-only guard self-tests | `scripts/test_*_guard.ps1` (four) | VERIFY | Not run on the prototype, where the drift above can only fail their CONTROL cases. They read the manifest, the register, the disposition record, the evidence file and the migrations, all in Write Scope. Step 4 runs all four on the working tree, where only that drift may fail; Step 7 runs them on the deployed state, where each must pass. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused tests, pgTAP A/B, the six HTTP suites, smoke and mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| SPP-5 and the disposition describe the local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |
| The four CI-only guard self-tests pass | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `app.derive_proof_reviewer()` is already the table's row-level BEFORE INSERT OR UPDATE trigger for every caller, and already owns the review columns (FX-4). Its INSERT arm stamped the session user as reviewer and judged nothing else. `app.enforce_catalog_codes` accepts any approval status, and the INSERT policy judges only the tenant and MANAGE_TENANT_SETTINGS. This contract changes that one function's INSERT arm and adds no trigger, function, constraint or framework.

Added Property: Through either door and for every caller, a payment proof is born `pending`, with no review time and no reviewer; only `app.platform_review_payment_proof` decides it, and that decision records no tenant reviewer.

Causal Negative: These are the pre-repair measurements in Business Reason, at `e26733a`:
- the RPC's proof born with its uploader as reviewer, kept through the platform's approval;
- a direct proof born `approved`, backdated, with forged review notes;
- a direct proof born `rejected`.

With FX-4's pre-repair function (`202607058900`, its exact text) installed inside test 152's own transaction, test 152 fails assertions 3, 4, 5, 6, 8, 11, 13, 14 and 16, each for its intended reason: the uploader named as reviewer, no exception where 23514 was required, the stated reviewer replaced by the session user, decided rows left behind, and the restored trigger not refusing.

Positive Test Design: One lapsed tenant with one branch and department; an `owner` and an `employee`; a rival tenant with a subscription and a payment-proof document. Positive controls:
- the owner is proven first (`app.current_user_id()`, MANAGE_TENANT_SETTINGS and VIEW_SUBSCRIPTION_STATUS held, REVIEW_SUBSCRIPTION_PAYMENT not);
- the RPC uploads a pending proof attributed to its uploader;
- a direct pending proof lands, its uploader derived and its stated reviewer discarded;
- the platform approves and reactivates the subscription.

Negative Test Design:
- **Birth state:** born `approved` (backdated, with forged review notes), born `rejected`, and `pending` with a review time are refused 23514 with the guard's message, signed in; born `approved` is refused session-less.
- **Reviewer:** none at birth, through either door, and none after the platform's approval.
- **Authority:** the owner's UPDATE to `approved` changes nothing.
- **Tenant:** a proof under the rival tenant is refused 42501 with RLS's message.
- **Partial writes:** only the two accepted proofs exist after every refusal.
- **PAR-4:** with `subscription_payment_proofs_derive_reviewer` dropped inside a savepoint, a proof is born `approved`; after the rollback the identical insert is refused again.

Non-Empty Population Obligation: Two tenants, one branch and department, two placed users with their roles, two subscriptions and a rival document. Every write and refusal is counted by row; no zero-row operation satisfies an assertion. The rival INSERT uses a literal one-row VALUES list.

Mutation Obligation: Out of file, record a surface: the md5 of `app.derive_proof_reviewer`'s source with the table's trigger definitions. For each mutant:
1. Install it inside test 152's own transaction and prove the surface differs.
2. Run test 152 and record the failing assertions.
3. Prove after the rollback that the surface equals the base.

A mutant whose installation is not proven is a harness error, never a kill.

| Mutant | Change | Expected to fail |
| --- | --- | --- |
| M1 | the reviewer stamped from the session on INSERT | 3, 8, 13 |
| M2 | the status arm removed | 5, 11, 14, 16 |
| M3 | the review-time arm removed | 6, 14 |
| M4 | session-less writers exempted from the birth rule | 11, 14, 16 |

Prototype result: base surface `106e640855e2e9ab13de468c63ab40b1`. Every installation changed the surface, and every rollback returned it to the base. All four were killed, exactly as listed.

Post-Implementation Proof Obligation: All of the following, on the final bytes and through canonical `-Finish`:
- the focused tests, a clean reset from the main checkout, pgTAP Pass A, the declared HTTP suite, pgTAP Pass B and smoke;
- the out-of-file mutations M1–M4 and the pre-repair causal negative;
- the generated artifacts, the four CI-only guard self-tests, repository consistency and `git diff --check`;
- fresh Primary evidence, parity evidence and the Primary ledger check.

## Implementation Steps

1. **Check** that `supabase/migrations/20261010160000_a_payment_proof_is_born_pending_and_unreviewed.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `cadb6f05e9c4f642b8b27fe6f93c91ae098eb674667eef84c47f2deba506c012`, md5 `f417ebb93516cb2c82f2b8e34da654cc`, 3208 bytes.
   - Its one statement replaces `app.derive_proof_reviewer()` with the function above. A comment block precedes it, stating the authority and SPP-5's measurements.
   - If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/152_a_payment_proof_is_born_pending_and_unreviewed_test.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `8bed225bc146d843695512a11621fb2d0380cc0308271b179a222c1eaa55dd5f`, `select plan(16);`.
   - Its `-- ATTACK-CLASSES:` line reads `AUTH TENANT DOOR STATE INPUT BUSINESS CONCURRENCY=N/A OBSERVABILITY=N/A PRIVILEGE=N/A REPLAY=N/A`, with each `N/A` reason in its header.
   - If the target exists with different bytes, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` already contains an `SPP-5` row. If not, make these edits and nothing else:
   - **Register:**
     - a 2026-10-10 Slice-38 freshness entry, with the previous one demoted to `Previously:`;
     - after the SPP-1/SPP-2 row, a new row SPP-5 (Medium, `M`), FIXED by SPEC-260 locally with Primary pending and Cert `🛡`, with the measurements above, Owner `—` and this contract as session;
     - at the end of FX-4's Status cell, a dated SPEC-260 sentence stating that its INSERT arm named the uploader as reviewer and that SPP-5 repairs it, with FX-4's Updated date set to `10-10`;
     - after the sentence in SPP-3's Evidence line that the column stays null after every review, a dated correction stating that from `202607058900` until SPEC-260 it did not.
   - **Disposition:**
     - a freshness entry, with the previous one demoted;
     - coverage 39 of 78 (16 `AUDITED`, 20 `AUDITED-OPEN`, 3 `PARTIAL`, 39 `NOT-RECORDED`) and the "All 39" line;
     - the `subscription_payment_proofs` row `AUDITED-OPEN` / `ADVERSARIAL` / SPEC-260 / SPP-5, SPP-3, FX-4, with its evidence and its swept non-defects. Its Next names SPP-3's trigger and, at that trigger, the platform review's unlocked read.

   The two files must then hash to the prototype's: register `b5bbeb2b5a6b0aabc9d54cd28d8e5621041aeb55031caabae3c3688a5a92af27`, disposition `5201e33682f5b236ecbdc0625a7b5755e78459d062871d5b36cd5dca5f0648d4`. If a target carries content other than its `e26733a` bytes before the edits, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 values:
   - a clean local reset from the main checkout; test 152 and the focused tests 35, 47, 48, 50, 62, 80, 83, 88, 89, 106 and 131;
   - pgTAP Pass A, all six HTTP suites, then pgTAP Pass B without reset; smoke and the plan sum;
   - the mutation evidence M1–M4 and the causal negative;
   - the API-contract and map generators;
   - the four `scripts/test_*_guard.ps1` on the working tree;
   - the scope check, `git diff --check` and repository consistency.

   Treat as expected at this boundary only:
   - an undeployed Primary;
   - the pre-deploy repository-consistency drift listed in Consumer Closure, and guard self-test CONTROL cases that fail only because of it.

   Read a fresh Primary baseline, read-only:
   - the project URL, the full ordered ledger and the absence of the target migration;
   - the function and structural surfaces;
   - `subscription_payment_proofs`' triggers; `app.derive_proof_reviewer`'s text md5, security mode, owner, configuration and ACL;
   - the tenant and payment-proof counts.

   Record the predicted delta.
5. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 4 and present the Gate-2 package. Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261010160000_a_payment_proof_is_born_pending_and_unreviewed`. If it is absent and deployment is separately authorized:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts, the table's triggers and the function's md5.
   - On an exact match, prove the transmitted text's md5 server-side, then apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires:
     - exactly one new row;
     - its stored statement md5 equal to the file's;
     - no existing target version.
   - Read fresh:
     - the ledger, the function surface and all ten structural surfaces;
     - the table's triggers;
     - the function's definition, security mode, owner, configuration and ACL;
     - the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with 464 HTTP assertions last passed on the Step-4 date.
   - Confirm that `supabase/tests` holds 152 files whose literal `plan(N)` values sum to 2810, then set `Suite **152 files / 2810 assertions**`. If either differs, stop.
   - Set Batch 6 coverage to 39 of 78, all thirty-nine at `ADVERSARIAL`.
   - Mark SPP-5 `DEPLOYED` with Cert `✅`, worded without a date beneath the register's freshness line.
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
     - set `Last Completed` to SPEC-260 / Slice 38;
     - set `Current Module` to Foundation Completion Programme Batch 6 resuming at Slice 39;
     - set `Next capability` to **Foundation Completion Programme — Batch 6 Slice 39**, naming the measured first target, followed by the existing Phase-8 order, closed-chapter and standing-fact sentences unchanged;
     - keep the manifest within 7000 characters;
     - regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate with `scripts/publish_candidate.ps1` and require exact-SHA candidate CI.
   - Promote the same accepted SHA, require main CI, and run `-Certify` for `REMOTE_CERTIFY: READY`.
   - Verify synchronized clean refs.

## Acceptance Criteria

- [x] A proof inserted with a status other than `pending`, or with a review time, is refused 23514 with the guard's message, signed in and session-less; the RPC's upload and a direct `pending` proof are accepted.
- [x] A proof has no reviewer at birth, through either door, and none after the platform's approval; a stated reviewer is discarded.
- [x] The held controls stay held: the owner's UPDATE approving its own proof changes nothing; a proof under another tenant is refused by RLS; the platform review approves and reactivates the subscription.
- [x] `app.derive_proof_reviewer` keeps its trigger, SECURITY INVOKER, owner `postgres`, `search_path=""` and ACL `{postgres=X/postgres}`; `app.upload_subscription_payment_proof` and `app.platform_review_payment_proof` are unchanged.
- [x] Mutants M1–M4 are each killed against test 152, with installation and restoration proven. The causal negative is recorded.
- [x] SPP-5 is fixed and deployed in the register, and FX-4's and SPP-3's statements are corrected.
- [x] `subscription_payment_proofs` is `AUDITED-OPEN` / `ADVERSARIAL` in the disposition record, and coverage is 39 of 78. No other surface's row changed.
- [x] The migration and test 152 matched their frozen SHA-256 values when applied.
- [x] Primary, the recorded evidence, the manifest (248 migrations; 152 files / 2810 assertions; 464 HTTP assertions), the API contract and `ai-map.json` agree, and the four CI-only guard self-tests and repository consistency pass.
- [x] The manifest names Batch 6 Slice 39 and its measured target as the next capability, with no Active Change Request.
- [x] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [x] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-10-10 — Gate 1 approval and execution started

- **Authority:** the owner's SPEC-260 Gate 1 approval of 2026-10-10 for Draft `b9542b9a86e1d8aeab4b7c5c1bebfb7767d23ca3`, contract SHA-256 `70f5ae61fb2cfea6dd51ecadc6f3fa6bfb8e0103d90195cb6cec9d453d1a255d`, migration SHA-256 `cadb6f05e9c4f642b8b27fe6f93c91ae098eb674667eef84c47f2deba506c012`, test 152 SHA-256 `8bed225bc146d843695512a11621fb2d0380cc0308271b179a222c1eaa55dd5f`. Verified before acting:
  - HEAD was that commit and the working tree was clean;
  - the contract file and its committed blob both hash to that value;
  - the frozen prototype files in the scratch worktree hash to the approved migration and test values, and the prototype's register and disposition record to `b5bbeb2b…` and `5201e336…`;
  - Write Scope is the nine paths above.

  Approval was committed at `c61e208`; its pre-commit Gate returned `APPROVAL_EVIDENCE: PASS`.
- **Preconditions:** the migration and test 152 are absent from the repository. The register, disposition record, API contract and Primary evidence file are unchanged since `e26733a`.
- **Publication range:** before this commit, `origin/main..HEAD` held 2 commits with 0 merges and was 0 behind.
- **The owner's four observations, assessed before any step:**
  1. **Session-less INSERT.** In the approved function the INSERT arm returns before the `auth.uid() is null` branch, so the birth rule binds every caller. Test 152 assertion 11 runs session-less as `postgres` and is refused, and mutant M4, which exempts session-less writers, is killed by assertions 11, 14 and 16. A row trigger fires for `service_role` as for any role; only `session_replication_role = replica` skips it, and only a superuser can set that. No platform path inserts a proof: `app.upload_subscription_payment_proof` is the only function that does. Step 4 also inserts a born-approved proof as `service_role` in a rolled-back transaction and records the refusal. No implementation is added.
  2. **Concurrent platform reviews: REPRODUCED, independent of SPP-5, and not repaired by this contract.** On the local stack at `b9542b9` (prototype migration applied), two committed fixture tenants each held one pending proof uploaded through the RPC. Session A called `app.platform_review_payment_proof` session-less and held its transaction for 6 s; session B called it on the same proof 2 s later. `pg_stat_activity` showed B waiting (`wait_event_type = Lock`), and once A committed, B proceeded:
     - **R1, A approves with terms (`professional`, `annual`), B rejects:** the proof ends `rejected` while the subscription is `active` / `annual`. The events read `subscription_payment_approved`, `subscription_activated` (`read_only -> active`), then `subscription_payment_rejected` from `pending`, a state the proof no longer held. There are two security events, `approved` and `rejected`.
     - **R2, A approves (`annual`), B approves (`monthly`):** one proof approved twice, two `subscription_payment_approved` events, two `subscription_activated` events (the second `active -> active`), two security events, and the subscription ends on B's `monthly` terms.

     The function reads the proof without a lock and updates it by id alone, so a second review that waited still writes. `47_…` assertion 16 holds only for sequential reviews. It is SUB-4's class (SPEC-250) one row earlier, reachable only by `postgres` and `service_role`. It is routed, unrepaired, to a separate corrective contract after this one, as the owner directed, and named in the Gate-2 package. The fixture tenants are erased by Step 4's reset from the main checkout. **Correction to the frozen disposition row:** Step 3's row, frozen by hash, says the race was "read from the code and not measured". It is now measured. Step 3 is applied as frozen, and the row's Next is corrected by that corrective contract.
  3. **Review-note provenance: no consumer misattributes it.** `review_notes` has two writers, the upload RPC and the platform review, and no reader: no function, view, materialized view or policy in the local catalog, and no Edge Function or script in the repository. The review's event records the platform's own `p_notes`, never the stored column. Recorded as a non-defect; no schema change.
  4. **Reviewer identity:** the repair derives `reviewed_by` as NULL and invents no platform identity. SPP-3 stays separate and owed on its own trigger, and the platform authorization boundary is unchanged.
- **Worktrees.** Read-only inventory, nothing modified:
  - `wt251` is clean at `578f3fb`;
  - `wt255` at `33e4db6` has 6 entries in `git status`, and `C:\w234` at `6c48fbb` has 15;
  - `owt/p2` is clean at `7fe62ed`.

  Unique work cannot be ruled out in the two dirty worktrees, and all four stay untouched. `wt260` holds only this contract's prototype bytes; its results are prototype evidence, never certification.
- **No Primary write is authorized.** Gate 2 stands before Step 6. Secondary is never contacted.

### 2026-10-10 — Pre-deploy readiness gate (Steps 1–4)

- **Steps 1–3 applied exactly as frozen** in the working tree, uncommitted until after deployment:
  - migration `cadb6f05e9c4f642b8b27fe6f93c91ae098eb674667eef84c47f2deba506c012` (md5 `f417ebb93516cb2c82f2b8e34da654cc`, 3208 bytes, 54 LF, 0 CR, ASCII), copied byte-for-byte from the prototype;
  - test 152 `8bed225bc146d843695512a11621fb2d0380cc0308271b179a222c1eaa55dd5f`;
  - the register (`b5bbeb2b5a6b0aabc9d54cd28d8e5621041aeb55031caabae3c3688a5a92af27`): the Slice-38 freshness entry, row SPP-5 after SPP-1/SPP-2, FX-4's dated sentence and Updated `10-10`, and SPP-3's dated correction;
  - the disposition record (`5201e33682f5b236ecbdc0625a7b5755e78459d062871d5b36cd5dca5f0648d4`): its freshness entry, coverage 39 of 78 (16 `AUDITED`, 20 `AUDITED-OPEN`, 3 `PARTIAL`, 39 `NOT-RECORDED`), "All 39", and the `subscription_payment_proofs` row `AUDITED-OPEN` / `ADVERSARIAL`.

  Each hash equals its frozen value, and no other line of either record changed.
- **Clean baseline, from the main checkout.** `npx supabase db reset` (exit 0, 1.6 min) applied the migration through the canonical loader.
  - The race and prototype fixtures were gone: 0 tenants with their ids.
  - Ledger 248, `207f3fad1a5d2a5b7d640f598c2050e9`, latest `20261010160000`. The canonical loader stores the migration as split statements, so the ledger row's joined md5 reads `4bdd1b85…`, not the file's.
  - Every structural surface equals the prototype's: functions `b3d4fc61413a43ef1ea60bc27a323b6e`/323 and combined `c93fb668bb243fa19274bed2605889ab`/3115; the other nine equal the recorded Primary evidence.
  - `app.derive_proof_reviewer` reads `prosrc` md5 `b3cda129c52b83db7739125b93c3e112`, SECURITY INVOKER, owner `postgres`, ACL `{postgres=X/postgres}`, `search_path=""`. The table keeps its three enabled triggers: `derive_reviewer`, `derive_uploader` and `enforce_catalog_codes`.
- **Focused tests, each passing in full:** 35 27/27, 47 19/19, 48 12/12, 50 5/5, 62 9/9, 80 19/19, 83 23/23, 88 25/25, 89 21/21, 106 16/16, 131 31/31, 152 16/16.
- **Suites, in `-Finish`'s order:**
  - pgTAP Pass A: `Files=152, Tests=2810`, `Result: PASS`;
  - HTTP: 35 + 40 + 85 + 122 + 122 + 60 = 464 passed, 0 failed;
  - pgTAP Pass B, without reset: 152 / 2810 PASS;
  - smoke: `ALL CHECKS PASSED (78 tables, … 71/622 catalog, …)`;
  - plan sum 152 files / 2810.
- **Mutation evidence, on the committed-path bytes:** base surface `106e640855e2e9ab13de468c63ab40b1`. M1–M4 each installed (surface changed) and restored (surface equal to base), failing exactly 3,8,13 / 5,11,14,16 / 6,14 / 11,14,16. With FX-4's pre-repair function installed, test 152 fails 3,4,5,6,8,11,13,14,16, as frozen.
- **Observation 1, the session-less INSERT boundary, measured (rolled back):**
  - `app.upload_subscription_payment_proof` is the only function that inserts a proof.
  - As `postgres`, session-less, a proof born `approved` is refused 23514 with the guard's message, and a session-less `pending` proof is accepted with no reviewer.
  - The local image grants `service_role` only REFERENCES, TRIGGER and TRUNCATE here, so its INSERT is refused for want of a grant. **Primary's platform image grants `service_role` INSERT, SELECT, UPDATE and DELETE on this table** (PAR-5; read below). With that grant emulated inside the transaction, a `service_role` proof born `approved` is refused 23514 by the repaired function. Against FX-4's pre-repair logic (its statements with the comments omitted, `prosrc` md5 `138886b4…`), the identical insert was **accepted, born `approved`**: on Primary today a service-role writer can file a decided proof, and this repair closes that door. After the rollback the function read `b3cda129…` again and the grant was gone.
- **Generated artifacts:** the API-contract generator, written to a scratch file, is byte-identical to the committed contract (`d28fb5672ca9c0795a99a74746069c973e1392edcc5e3d2a5a315348138175fd`): 80 RPC endpoints, 8 views, 74 tables. `ai-map.json`, stored LF, changes only its `generated_at`. That regeneration was not kept; Step 7 regenerates it.
- **Scope:** `origin/main..` plus untracked touches exactly the manifest, `ai-map.json`, this contract, the register, the disposition record, the migration and test 152, all in Write Scope. `git diff --check` exit 0.
- **Repository consistency:** exactly the expected pre-deploy drift, 6 issues in all:
  - 247 vs 248 migrations;
  - latest `20261010140000` vs `20261010160000`;
  - fingerprint `f2fd1294…` vs `207f3fad…`;
  - 151 vs 152 files and 2794 vs 2810 assertions;
  - RECOVER-1 (2 issues).

  Checks 21–28 are clean.
- **The four CI-only guard self-tests, on this working tree:** all four run on the working tree with Steps 1–3 applied:
  - `test_future_date_guard` passed (exit 0, 3.6 min);
  - `test_status_contradiction_guard` passed (exit 0, 3.7 min);
  - `test_primary_ledger_guard` failed only its two CONTROL cases (0.3 min);
  - `test_cold_start_state_guard` failed only its nine CONTROL, second-direction CONTROL and restore cases (CONTROL; A2, C2 and E CONTROL; A-, B-, C- and D-restore; second direction; 4.2 min).

  Each failing case requires an untouched copy of the repository to be CLEAN, which the drift above prevents until Step 7. Every mutation case passed. No guard needs a file outside Write Scope. Step 7's run, where each must pass, stays mandatory.
- **Fresh Primary baseline, read-only (`vrvtsxexkiiiivlkdxzp`, URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`):**
  - ledger 247, `f2fd129466f76536d53779a131cda874`, latest `20261010140000`; no row for the target version or name, and none after `20261010140000`;
  - functions `b526e294da3ac335350d2ad3758971e4`/323;
  - `parity_surface.sql`'s ten surfaces equal the recorded evidence: combined `2e608d8e6162a3a466583fe2bb327566`/3115;
  - `subscription_payment_proofs` carries its three triggers, all enabled, RLS on; grants `authenticated` INSERT, SELECT and UPDATE, and `service_role` DELETE, INSERT, REFERENCES, SELECT, TRIGGER, TRUNCATE and UPDATE;
  - `app.derive_proof_reviewer`: `prosrc` md5 `037078ce190d9980d8429f74ec63545c` (definition `745eb8c2792ac249688c3f224afac186`), SECURITY INVOKER, owner `postgres`, ACL `{postgres=X/postgres}`, `search_path=""`;
  - 0 tenants, 0 subscriptions, 0 payment proofs.
- **Predicted delta on Primary:**
  - ledger 248 / `207f3fad1a5d2a5b7d640f598c2050e9`, latest `20261010160000`;
  - functions `b3d4fc61413a43ef1ea60bc27a323b6e`/323;
  - the function's `prosrc` from `037078ce…` to `b3cda129c52b83db7739125b93c3e112`;
  - combined `c93fb668bb243fa19274bed2605889ab`/3115.

  Triggers, policies, constraints, grants, columns, views, indexes, status transitions and RLS are unchanged. No business row is written.
- **Material finding outside this contract (Begin entry, observation 2):** the two-session race on `app.platform_review_payment_proof` stays reproduced and unrepaired. It is routed to a separate corrective contract after this one.
- **Stop at Gate 2.** No exact-byte owner authorization for the migration is recorded. Step 5 stops here. Secondary was not contacted.
### 2026-10-10 — Human Gate 2: owner authorization

- **Authority:** the owner's SPEC-260 Gate 2 authorization of 2026-10-10. It covers exactly the migration `supabase/migrations/20261010160000_a_payment_proof_is_born_pending_and_unreviewed.sql`, SHA-256 `cadb6f05e9c4f642b8b27fe6f93c91ae098eb674667eef84c47f2deba506c012`, MD5 `f417ebb93516cb2c82f2b8e34da654cc`, 3208 bytes, 54 lines, ASCII, LF-only, to Primary `vrvtsxexkiiiivlkdxzp` only, by the approved procedure. Nothing else on Primary, and nothing on Secondary `brplkqmbzffpxqgkkdzo`.
- **Not authorized:** the correction of the platform-review race (Begin entry, observation 2), or any other Primary change. The owner classes that race as a proven, independent correctness and financial-entitlement finding, to be assessed by priority after this contract is certified and before ordinary Batch 6 selection resumes.

### 2026-10-10 — Step 6: Primary deployment

- **Local recheck, immediately before the write:**
  - HEAD `616507b9a9167e5b8f4702c9e6eedcd8f15df58e` on the chain `b9542b9 → c61e208 → 4faaf29 → 616507b`, 0 behind `origin/main` `e26733a`;
  - Draft `b9542b9`'s contract hashes to `70f5ae61…`, and since then this contract changed only its status lines and its Execution Log;
  - the migration hashes to its frozen identity (3208 bytes, 54 LF, 0 CR, ASCII), and test 152 to `8bed225b…`; the register (`b5bbeb2b…`) and disposition record (`5201e336…`) hash as Step 3 left them;
  - the working tree touches only Write Scope paths, and the stash is empty.
- **Primary recheck, read-only:**
  - URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`;
  - ledger 247 `f2fd129466f76536d53779a131cda874`, latest `20261010140000`, the target absent by version and name, no row after it;
  - all ten structural surfaces equal the recorded evidence: functions `b526e294…`/323, combined `2e608d8e…`/3115;
  - the function: prosrc `037078ce190d9980d8429f74ec63545c`, definition `745eb8c2792ac249688c3f224afac186`, SECURITY INVOKER, owner `postgres`, ACL `{postgres=X/postgres}`, `search_path=""`;
  - the table: three enabled triggers (`derive_reviewer`, `derive_uploader`, `enforce_catalog_codes`), RLS on, grants unchanged from the Step-4 read;
  - 0 tenants, subscriptions and payment proofs.
- **Server-side proof:** the transmitted text hashed on Primary to MD5 `f417ebb93516cb2c82f2b8e34da654cc`, 3208 bytes, 54 LF, 0 CR.
- **Apply:** that same text, through the Primary connector's `apply_migration`, returned success. A fresh read showed one new row, temporary version `20261010204356`, with one stored statement, MD5 `f417ebb9…`, 3208 bytes, and 248 rows in all.
- **Reconciliation:** one guarded UPDATE renamed only that row to `20261010160000`. Every guard held, and it renamed 1 row:
  - 248 rows;
  - exactly one row after `20261010140000`;
  - the other 247 hashing to `f2fd1294…`;
  - the statement MD5 equal to the file's;
  - no existing target.
- **Fresh post-write reads (`2026-10-10T20:44:17Z`):**
  - ledger 248 `207f3fad1a5d2a5b7d640f598c2050e9`, latest `20261010160000`, exactly one row for the migration, the temporary version gone;
  - functions `b3d4fc61413a43ef1ea60bc27a323b6e`/323, the other nine surfaces unchanged, combined `c93fb668bb243fa19274bed2605889ab`/3115, each equal to the prediction;
  - the function: prosrc `b3cda129c52b83db7739125b93c3e112` and definition `257a9fa2c086318865ae9f7a12f0ab9a`, each equal to local; SECURITY INVOKER, owner `postgres`, ACL `{postgres=X/postgres}`, `search_path=""`;
  - the same three enabled triggers, RLS on, unchanged grants;
  - 0 tenants, subscriptions and payment proofs. No business-data write.
- **Secondary** `brplkqmbzffpxqgkkdzo` was not contacted.

### 2026-10-10 — Step 7: evidence and measured state

- **The evidence file, `reports/evidence/primary-ledger-evidence.json`,** was written from the fresh post-write readings only:
  - `read_at` `2026-10-10T20:44:17Z`;
  - `repository_head` `616507b9…`;
  - 248 migrations, `207f3fad…`;
  - functions `b3d4fc61…`/323, structural `c93fb668…`/3115;
  - the ledger list appends `20261010160000_a_payment_proof_is_born_pending_and_unreviewed`. It equals the repository's 248 migration files, and its fingerprint recomputes to `207f3fad…`.
- **Manifest:** `Live state` reads 248 migrations, the new ledger, function and structural hashes, and `Suite **152 files / 2810 assertions**`, with 464 HTTP assertions last passed 2026-10-10. Coverage reads 39 of 78, all thirty-nine at `ADVERSARIAL`. `supabase/tests` holds 152 files whose literal `plan(N)` values sum to 2810.
- **Register:** SPP-5 reads `DEPLOYED to Primary under separate exact-byte owner authorization`, with Cert `✅`.
- **Generated artifacts:** `MASTER_API_CONTRACT.md` regenerates unchanged (`d28fb567…`; 80 RPC endpoints, 8 views, 74 tables). `ai-map.json` is regenerated and stored LF; only `generated_at` changed.
- **Runtime Checkpoint** is `DONE`.
- **Checks:** `check_primary_ledger.ps1`: RECOVER-1 `CLEAN`; `check_database_parity_evidence.ps1`: `DATABASE PARITY: CLEAN` and `PRIMARY PARITY EVIDENCE: CLEAN`; repository consistency: `CLEAN`; `git diff --check`: exit 0.
- **CI-only guard self-tests, on this deployed state:** `test_future_date_guard` 18/0, `test_status_contradiction_guard` 33/0, `test_primary_ledger_guard` 13/0 and `test_cold_start_state_guard` 34/0, each exit 0 (3.3, 3.0, 0.3 and 4.7 min). The CONTROL and restore cases that the pre-deploy drift failed at Step 4 now pass.
### 2026-10-10 — Post-deploy local certification

Canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` ran on the clean, committed HEAD `643870e` in VERIFY mode (`STATUS: In Progress`, `STEP: DONE`), with profiles DATABASE and REPOSITORY plus the declared `verify_journey_branches.ps1`, and nothing else running. It reported `LOCAL_CERTIFY: READY` in 5.7 min, and every mandatory verification passed in that run:
- reset; pgTAP Pass A; `verify_journey_branches.ps1`; pgTAP Pass B; smoke;
- `check_database_parity_evidence.ps1`, repository consistency, `git diff --check` and `check_primary_ledger.ps1`.

Before it, on the same committed state, the four CI-only guard self-tests passed (Step 7). The mutation evidence (M1–M4 and the causal negative), observation 1's rolled-back service-role measurement, the two-session race reproduction and the six HTTP suites (464/0) were recorded at Steps 1–4 on the same migration and test bytes, which are unchanged, so they were not repeated.

**Selector after SPEC-260** (`scripts/batch6_select_target.ps1`, 39 surfaces still `NOT-RECORDED`), as Exposure/coverage:
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

Slice 39's measured target is `complaints`.

**Owner direction at Gate 2 (2026-10-10):** after this contract is certified, the reproduced race on `app.platform_review_payment_proof` (Begin entry, observation 2) is to be assessed by priority before ordinary Batch 6 selection resumes. That assessment determines its finding identity and smallest lawful corrective scope, and corrects the disposition row's "not measured" wording through the next authorized Write Scope. Nothing in this contract repairs it, and its Gate 2 did not authorize that correction.

## Verification Notes

### 2026-10-10 — Independent Review of the execution commit `643870e`

Reviewed the committed tree against the approved Draft `b9542b9`, the Gate-2 authorization and the nine-path Write Scope. The review read the implementation and the live state, not the Execution Log.

1. **Birth state (criterion 1).** The committed `app.derive_proof_reviewer` refuses, on INSERT and before any session test, a `status_code` distinct from `pending` or a non-null `reviewed_at` (23514, the guard's message). Test 152 assertions 4, 5 and 6 assert the signed-in `approved`, `rejected` and review-time cases, and 11 the session-less `approved` case; 2 and 7 accept the RPC's upload and a direct `pending` proof. Test 152 passes 16/16 on the certified stack, and both `-Finish` pgTAP passes ran it within the whole suite and reported PASS.
2. **Reviewer (criterion 2).** The INSERT arm sets `new.reviewed_by := null` for every caller. Assertions 3 (the RPC's proof), 8 (a stated reviewer discarded at the table door) and 13 (after the platform's approval) assert a NULL reviewer.
3. **Held controls (criterion 3).** Assertion 10 asserts that the owner's UPDATE approving its own proof changes nothing, 9 that a proof under a rival tenant is refused 42501 by RLS, and 12–13 that the platform review approves the proof and the subscription reads `active`. Assertion 14 asserts that no refused write left a row.
4. **Function properties (criterion 4).** The migration contains exactly one statement, `create or replace function app.derive_proof_reviewer()`. On Primary and locally the function reads prosrc `b3cda129…` and definition `257a9fa2…`, SECURITY INVOKER, owner `postgres`, `search_path=""`, ACL `{postgres=X/postgres}`, and the table keeps its three enabled triggers. `app.upload_subscription_payment_proof` and `app.platform_review_payment_proof` are untouched by the range. Comment-stripped and whitespace-normalized, they read `084aef4c…` and `d7e7c471…` on both sides. Raw `prosrc` differs only because Primary's stored text carries no comments, which is pre-existing and invisible to the function surface, which agrees (`b3d4fc61…`/323).
5. **Mutation (criterion 5).** M1–M4 were recorded at Step 4 on the committed-path bytes, which are unchanged (`cadb6f05…`, `8bed225b…`). Each was installed (surface changed) and restored (surface equal to base), failing exactly 3, 8, 13 / 5, 11, 14, 16 / 6, 14 / 11, 14, 16. The causal negative fails 3, 4, 5, 6, 8, 11, 13, 14 and 16 on FX-4's pre-repair function.
6. **Register (criterion 6).** SPP-5 reads FIXED and DEPLOYED with Cert `✅`. FX-4 carries the dated SPEC-260 sentence with Updated `10-10`, and SPP-3's Evidence line its dated correction. Against `e26733a`, no other row changed besides the freshness entry.
7. **Disposition (criterion 7).** `subscription_payment_proofs` is `AUDITED-OPEN` / `ADVERSARIAL`, and the counts read 39 of 78 (16 `AUDITED`, 20 `AUDITED-OPEN`, 3 `PARTIAL`, 39 `NOT-RECORDED`). No other surface row changed against `e26733a`. Its Next cell's "not measured" for the review read is now stale (Begin entry, observation 2). The next authorized Write Scope corrects it.
8. **Frozen values (criterion 8).** The committed migration and test 152 blobs hash to `cadb6f05e9c4f642b8b27fe6f93c91ae098eb674667eef84c47f2deba506c012` and `8bed225bc146d843695512a11621fb2d0380cc0308271b179a222c1eaa55dd5f`.
9. **Agreement (criterion 9).** Primary, the evidence and the manifest agree:
   - 248 migrations, `207f3fad…`;
   - functions `b3d4fc61…`/323, structural `c93fb668…`/3115;
   - 152 files / 2810 assertions, 464 HTTP assertions.

   The API contract matches its generator (`d28fb567…`), and `ai-map.json` is LF. The four guard self-tests, repository consistency and `-Finish`'s parity and ledger checks pass.
10. **Next capability (criterion 10).** The Complete commit names Batch 6 Slice 39 and `complaints` (8/48) and clears the Active Change Request.
11. **Primary and Secondary (criterion 11).** Primary's ledger holds exactly one row for the migration, its statement MD5 `f417ebb9…` equal to the authorized file, after one guarded rename of temporary version `20261010204356`. It holds 0 tenants, subscriptions and payment proofs before and after. Secondary was never contacted.
12. **Scope (criterion 12).** `e26733a..HEAD` changes only Write Scope paths, and `MASTER_API_CONTRACT.md` regenerates unchanged.

**Outside this contract, and not a defect in it:** the two-session race on `app.platform_review_payment_proof` stays reproduced and unrepaired. Per the owner's Gate-2 direction, it is assessed by priority before Slice 39.

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

- **EARN IT.**
  - SPP-5 was reproduced by an owner on a lapsed tenant, through the RPC and at the table door, and the held doors were measured beside it.
  - Test 152 fails 9 assertions for their intended reasons with FX-4's pre-repair function installed.
  - Each arm of the repair is pinned by an installed, killed mutant, and the trigger itself by PAR-4's pair.
  - Primary was read, not written: 0 proofs, ledger 247, latest `20261010140000`, and the function's `prosrc` md5 `037078ce…`.
- **WORTH IT.**
  - The record of who decided a payment proof said the tenant decided it, on every proof through the sanctioned door, which is the one thing canon 28 says a tenant cannot do.
  - A tenant could also file a platform decision the platform never made.
- **SIMPLIFY IT WITHOUT WEAKENING.**
  - One existing function's INSERT arm, in SPEC-257's entry-state shape. No trigger, table, column, grant, policy, constraint, permission or other function changes.
  - Every legitimate upload, through either door, still works.
- **Owner direction (2026-10-10).** The owner named Batch 6 Slice 38 and authorized PLAN and Draft preparation only. `CR_LIFECYCLE.md` makes `Draft -> Approved` a human act, so this Draft stops at Gate 1. Approval, when given, still does not authorize any Primary write; Gate 2 is separate.
- **Deliberately not changed:**
  - `app.platform_review_payment_proof`'s unlocked read (Held, routed to SPP-3's trigger);
  - the upload note's home in `review_notes`;
  - `uploaded_at`, which has no reader;
  - `scripts/batch6_select_target.ps1`'s order inside a tie, which is visible in its output and decides nothing;
  - canon 09, 26, 27, 28 and 31;
  - the n8n workflow, PH8-10 and Phase 8;
  - the registered worktrees `wt251`, `wt255`, `owt/p2` and `C:\w234`.
