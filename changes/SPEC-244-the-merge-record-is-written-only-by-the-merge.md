# Change Request — SPEC-244

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Foundation Completion Programme Batch 6 Slice 31: give `public.customer_identity_merges` a truthful disposition. Close MRG-1, a merge record written or rewritten at the table door without a merge, and MRG-2, a second merge of one identity admitted by an archive flag the customers door can reverse. The merge record must be written only by `app.merge_customer_identity`, and that merge must judge an identity merged by its own record. Record the surface `AUDITED`, and set the next capability to the Slice-32 target the selector then measures.

This contract does not touch n8n, the Data Manager workflow, the Direct Call Quality Feedback Loop, PH8-10, Smart Bidding, BOOK-11, BOOK-12, PAY-5, CONV-9 or CONV-10.

## Business Reason

- **Selection, measured.** `scripts/batch6_select_target.ps1` at `368a881` ranks `customer_identity_merges` first: `NOT-RECORDED`, Exposure 8, coverage 24, 4 test files. Its components are 2 direct writes, 1 SECURITY DEFINER writer and 1 RPC. The runner-up is `journal_entry_lines` at 8/26. This matches Slice 30's recorded runner-up.
- **The surface's authority.**
  - ADR-0019: `app.merge_customer_identity` re-points every reference to the source, writes the merge record, emits the critical `customer_identity_merged` event and archives the source.
  - SPEC-240's amendment makes the record the consent authority. `app.customer_consent_status` reads the logical customer through it, and `app.record_customer_consent` refuses an identity it names as merged.
  - `202607059300` calls the table "an append-only audit log of a destructive operation".
  - Exactly one function in the database writes it: the merge, which is SECURITY DEFINER.
  - No application code, script or view writes it, and no policy reads it.
  - Yet `authenticated` held INSERT, SELECT and UPDATE, guarded only by `app.guard_write_capability` (MERGE_CUSTOMER_IDENTITY, held by `owner` and `ceo`) and `app.derive_merge_actor`. The API contract lists the table as `SIU-` through PostgREST.
- **MRG-1 (High, latent), measured on the local stack at `368a881`, rolled back.** One tenant had an `owner` holding MERGE_CUSTOMER_IDENTITY at aal2 and an `employee` handler. Customer A recorded DENIED and owns a qualified Google Ads call lead; customer B recorded GRANTED.
  - The employee's direct INSERT was refused, as the positive control.
  - The owner's direct INSERT of "A merged into B" committed. A stayed active, its lead and conversion stayed on A, and no merge event was recorded.
  - Yet `app.customer_consent_status` turned A's `denied` into `granted`. The claim released A's `qualified_phone_call` with A's phone `+201000003111`. A's own new withdrawal was refused as "merged into" B.
  - After a genuine merge of C into D, the owner's direct UPDATE moved the record to E → F, changed its reason and dated it 2001, while `merged_by` stayed frozen and the one event still named C → D. D lost C's DENIED (read NULL), and E, which had never been merged and held no record, read F's GRANTED.
  - A direct self-merge row made D read NULL.
  - Over HTTP, the owner's `POST /rest/v1/customer_identity_merges` returned 201, and a `PATCH` returned 204 and rewrote the record.
  - **Classification:** the table door is not a business door. ORVION has one merge, and the record exists to describe it.
- **MRG-2 (Medium, latent), measured at `368a881`, rolled back.** The merge's replay refusal ("source customer is already archived (merged?)") and target refusal read `customers.is_archived`. An ARCHIVE_RECORD holder may clear that flag at the customers door: CUST-11's authority, which an `owner` holds.
  - **Fork:** the owner merged A into B, un-archived A and merged A into C. The record named A merged into both survivors, and B's later withdrawal governed A and B but never reached C.
  - **Cycle:** the owner merged E1 into E2, un-archived E1 and merged E2 back into E1. Both identities then read NULL consent, and both were refused any new decision, a withdrawal included, while E1 stayed active.
- **The repair**, the smallest correction at the authority that owns each fact:
  - **MRG-1:** revoke INSERT and UPDATE on the table from `authenticated`. SELECT stays. The SECURITY DEFINER merge runs as the table's owner and never needed the grant. This is `202607056100`'s rule, re-ratified by slices 6 and 8: a write grant is kept exactly where a sanctioned writer needs it. `app.guard_write_capability` and `app.derive_merge_actor` stay attached; they still fire inside the merge.
  - **MRG-2:** the merge also refuses a source, or a target, that the record names as merged away. It reads the record after its existing archive refusals, under the row locks it already takes, so every existing refusal keeps its order and message.
  - The rest of the merge body is byte-identical to SPEC-240's.
- **Considered and rejected:**
  - Duplicating the merge in triggers to keep a table door: a second merge engine.
  - A CHECK for every refusal the merge makes: the door is closed, so the merge is the only writer.
  - Immutability triggers for the platform role.
  - Changing the customers archive door, which is CUST-11's.
  - Rewriting ADR-0019, whose architecture holds.
- **Held, recorded so a later slice does not rediscover it:**
  - **Concurrency.** Six two-session proofs, each with an observed `pg_blocking_pids` edge. A→B against B→A, and A→B against A→C, each left one merge and an active survivor, with the loser refused for its own lifecycle reason. A merge against a consent decision on the source, in both orders: the decision waits and is then refused toward the survivor, or it lands first and governs both. A merge against a decision on the target, in both orders: both are serialized, and the target's denial governs both.
  - **Tenant isolation:** RLS `tenant_isolation` and composite `(tenant_id, …)` keys.
  - **No DELETE grant.**
  - **The 16 references to `customers`:** 14 are re-pointed by catalog discovery, and two are ADR-0019's documented exclusions.
  - **`customer_consents`** is append-only with no table door; **`events`** is read-only to sessions.
  - **Contact-method collisions** stay CUST-1's and CM-2's.
  - **`service_role`'s TRUNCATE** is PAR-5's.
  - **An un-archived merged source** stays an alias. It is still merged in the record, reads its survivor's consent and records none.

## Risks

- **A legitimate writer losing its door.** Mitigated by measurement:
  - one function writes the table, and it is SECURITY DEFINER;
  - no script, view or application path writes it;
  - pgTAP 144 files / 2638 assertions and all six HTTP suites pass on the prototype.
  - Test 87 used a direct INSERT as ATTR-2's positive control. It now proves the same attribution through the merge, which is the only legitimate path.
- **A merge refused that should proceed.** The new refusals fire only for an identity the record already names as merged away, which can arise only after its archive flag was cleared. A normal merge, its replay refusal and the reciprocal-merge refusal keep their messages: Tests 71 and 111 and `verify_customer_concurrency.py` are unchanged and pass.
- **Primary deployment** revokes two table privileges and replaces one function body. Primary holds 0 merge records. It requires separate exact-byte owner authorization (Gate 2); approving this contract does not authorize it.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-244-the-merge-record-is-written-only-by-the-merge.md`
- `supabase/migrations/20261007190000_the_merge_record_is_written_only_by_the_merge.sql`
- `supabase/tests/144_the_merge_record_is_written_only_by_the_merge_test.sql`
- `supabase/tests/87_actor_attribution_second_door_test.sql`
- `scripts/verify_role_journeys.ps1`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607044900_merge_customer_identity.sql`
- `supabase/migrations/202607059300_the_hand_that_records_is_not_always_the_hand_that_acted.sql`
- `supabase/migrations/20260909114354_customers_slice11_closure.sql`
- `supabase/migrations/20260929160000_a_google_ads_call_qualifies_as_a_phone_call.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/53_api_surface_test.sql`
- `supabase/tests/57_write_capability_map_test.sql`
- `supabase/tests/58_write_grants_and_config_capability_test.sql`
- `supabase/tests/71_customer_identity_merge_test.sql`
- `supabase/tests/111_customer_surface_test.sql`
- `supabase/tests/142_a_google_ads_call_qualifies_as_a_phone_call_test.sql`
- `reports/architecture-decision-records.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_INTEGRATION_CATALOG.md`
- `_ORVION_CANONICAL/31_schema_draft.md`
- `_ORVION_CANONICAL/32_execution_roadmap.md`
- `scripts/verify_database.sql`
- `scripts/verify_customer_concurrency.py`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `reports/architecture-decision-records.md` ADR-0019, including its 2026-09-29 amendment
- `reports/master/MASTER_EXECUTION_PLAN.md` Batch 6 method and EC-1…EC-11; `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_GAP_REGISTER.md` (CUST-1, CUST-8, CUST-11, CUST-12, ATTR-2, IDENT-3, AUDIT-4)
- `changes/SPEC-070-merge-customer-identity.md`; `changes/SPEC-240-a-google-ads-call-qualifies-as-a-phone-call.md`
- Current local `app.merge_customer_identity`, `app.derive_merge_actor`, `app.guard_write_capability`, `app.customer_consent_status`, `app.record_customer_consent`, `app.claim_conversion_deliveries`
- Tests 57, 58, 71, 87, 111, 142

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

- `pwsh -NoProfile -File scripts/verify_role_journeys.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| `authenticated` loses INSERT and UPDATE on `customer_identity_merges` | Test 87 (ATTR-2/E's direct INSERT); Tests 10, 53, 57, 58; the PostgREST table door; `verify_role_journeys.ps1` | WRITE | The prototype was applied as a real migration on a clean reset in scratch worktree `C:\w31` at `368a881`: migration SHA-256 `8286493bc96dd795baea727252acc8a4fcf1e3efa77bea0ffcd1ce6100329c85`. The full suite against it, before Test 87 was edited, failed only Test 87 assertions 19-20 (the direct INSERT positive control). Test 87 now merges through the RPC and asserts the same attribution (SHA-256 `0671672e35dd54ce9a6f789dc0c2a7a2f07f405b26f8470338b40f860aa7a792`, 29/29). Tests 10, 53, 57 and 58 pass unchanged. `verify_role_journeys.ps1` gains two checks (SHA-256 `a69f843841e16583c90060f2220539d29b8e030608bc3d3e609eab7e2e7d8278`): with the grants restored they FAIL (POST 201; PATCH 204 with the record rewritten), and on the repair they pass (122/0). |
| The merge body gains two record refusals | Tests 71, 111, 142; `verify_customer_concurrency.py`; `verify_role_journeys.ps1`'s merge block | VERIFY | Every existing refusal keeps its order and message; Tests 71, 111 and 142 pass unchanged, and the six two-session proofs pass on the sanctioned path. |
| The consent reader and writer | `app.customer_consent_status`, `app.record_customer_consent`, the claim | VERIFY | Unchanged functions; Test 142 passes unchanged; Test 144 proves the consequence through the real claim. |
| The table's generated API row | `MASTER_API_CONTRACT.md` | WRITE | The generator reports 80 RPC endpoints (80 with HTTP evidence), 8 views and 74 tables. Exactly two lines move: the table's row `SIU-` → `S---`, and `merge_customer_identity`'s refusal count 7 → 9 (prototype SHA-256 `d8ef4dc6ae433fe7748d823af057f4e4ce7d64f4ecea12af86a6559829943ef8`). `ai-map.json` differs only in `generated_at`. |
| Suite, HTTP and smoke | full pgTAP; the six HTTP suites; `scripts/verify_database.sql` | VERIFY | On the prototype, on a clean reset, in `-Finish`'s order: pgTAP Pass A 144 files / 2638 assertions PASS (2615 + 23); HTTP 35 + 40 + 74 + 122 + 122 + 60 = 453 passed, 0 failed; Pass B 144 / 2638 PASS; smoke `ALL CHECKS PASSED (78 tables, … 71/622 catalog, …)`. `scripts/verify_database.sql` pins nothing on this table and is unchanged. |
| Measured state that moves | manifest (`Live state`, suite and HTTP figures, coverage, Last Completed, Current Module, Next capability); `primary-ledger-evidence.json`; `ai-map.json`; Checks 5, 7, 9, 15, 19, 22, 24 | WRITE | 240 → 241 migrations, latest `20261007190000`; 143 → 144 files, 2615 → 2638 assertions; HTTP 451 → 453; coverage 31 → 32 of 78. Tables (78), catalog (71/622) and client RPCs (80) do not move. Primary values are written only from fresh post-deploy readings. |
| MRG-1 and MRG-2 recorded; the surface `AUDITED` | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 22 and 24 | WRITE | Prototype SHA-256 values: register `ec10970d1599dae1d11c4e907464dacf08a9e605b5baa3c3674afe25b129d31d`, disposition `dc2569fc1fbfcf58a50604c9a2ad2483a5d4bdac680af9c6728def2594936628`. |
| CI-only guard self-tests | `scripts/test_*_guard.ps1` (four) | VERIFY | On the prototype, future-date (18/0) and status-contradiction (33/0) pass. Primary-ledger (2 failed) and cold-start (9 failed) fail only their clean-repository CONTROL cases, as at SPEC-243's same boundary. Repository consistency reports the six expected pre-deploy issues: three migration-state drifts, two suite-figure drifts and RECOVER-1. It also reports one prototype-only issue: the disposition's session pointer to this contract, which the prototype tree lacks. No pinned figure moves: the open-decision line keeps MAIL-1, RET-1 and PH8-10. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused tests, pgTAP A/B, the six HTTP suites, smoke and mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| MRG-1, MRG-2 and the disposition describe the local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |
| The four CI-only guard self-tests pass | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `202607056100`'s grant rule (a write grant is kept exactly where a sanctioned writer needs it), applied unchanged to the table whose one writer is SECURITY DEFINER; and the merge's own refusals, read under the locks it already takes. No new trigger, table, permission, event type or lineage structure. Rejected:
- a trigger reproducing the merge so the table door could stay;
- CHECKs restating the merge's refusals;
- platform-role immutability triggers;
- a change to the customers archive door;
- an amendment to ADR-0019.

Added Property: A customer merge record exists only where `app.merge_customer_identity` performed that merge, and no signed-in user can create or rewrite one. An identity is merged away at most once, and never into an identity that was itself merged away, whatever its archive flag. So the consent reader always finds one survivor for a merged identity, and a customer that was never merged answers only to its own decisions.

Causal Negative: The pre-repair measurements in Business Reason, at `368a881`, rolled back. A forged row made A's DENIED read GRANTED, A's call was claimed, and A's withdrawal was refused. A rewrite moved a genuine merge and backdated it. An un-archive plus re-merge forked the lineage and closed a cycle. Over HTTP the POST and PATCH landed.

Positive Test Design: One tenant: an `owner` (MERGE_CUSTOMER_IDENTITY, ARCHIVE_RECORD, aal2) and an `employee` handler who qualifies a Google Ads call lead of A and records consent. A has DENIED, B GRANTED and C DENIED; C carries a note. The owner merges C into D through the merge. A grants later, and its call is claimed. The survivor D takes a new decision. A second tenant's owner attacks across the boundary.

Negative Test Design:
- **MRG-1:** the owner's direct INSERT and its direct UPDATE of every column are refused by the missing grant. A's consent, B's consent, the empty claim and A's ability to withdraw prove the consequence did not happen.
- **MRG-2:** after the owner un-archives C, merging C again and merging D into C are refused by the record.
- **Kept refusals:** the employee (privilege), the owner at aal1 (step-up), the other tenant (read and merge), the archived-source replay and the self-merge stay refused.
- **Observability:** one record, one event and an active survivor after every refused attempt.

Non-Empty Population Obligation: Two tenants with active enterprise subscriptions. Tenant one has a branch, a department, two users, five customers, a note, a qualified lead with its conversion and three consent records. Tenant two has its owner.

Mutation Obligation: Out of file, record the md5 of a surface covering the merge's definition and the table's ACL. For each mutant:
1. Install it and prove the md5 differs.
2. Run Test 144 and record the failing assertions and how many of 23 ran.
3. Restore it and prove the md5 matches the base.

A mutant whose installation is not proven is a harness error, never a kill. A mutant killed only by an unrelated refusal is not counted.

| Mutant | Change | Expected to fail |
| --- | --- | --- |
| M1 | `authenticated` INSERT restored | 3 |
| M2 | `authenticated` UPDATE restored | 10 |
| M3 | the source record check removed | 19 |
| M4 | the target record check removed | 20 |

Prototype result: base surface md5 `eb747464e820ccc17f02e4dabc2d734d`. Every installation was proven by a changed md5 and every restoration by the base md5, and Test 144 passed again afterwards.

| Mutant | Failing assertions | Ran of 23 |
| --- | --- | --- |
| M1 | 1, 3, 4, 5, 6 | 6 |
| M2 | 1, 10, 11, 19, 20, 21, 23 | 23 |
| M3 | 19, 20, 21 | 23 |
| M4 | 20, 21, 22 | 23 |

M1's run stops after assertion 6. A is then recorded as merged, so the next fixture call to `app.record_customer_consent` raises. Its named kill is assertion 3, followed by its consequences 4–6. Assertion 1 is the premise: on its own it does not count as a kill.

Post-Implementation Proof Obligation: All of the following, on the final bytes and through canonical `-Finish`:
- the focused tests, a clean reset, pgTAP Pass A, the declared HTTP suite, pgTAP Pass B and smoke;
- the out-of-file mutations and the pre-repair causal negative;
- the six two-session proofs;
- the generated artifacts, the four CI-only guard self-tests, repository consistency and `git diff --check`;
- fresh Primary evidence, parity evidence and the Primary ledger check.

## Implementation Steps

1. **Check** that `supabase/migrations/20261007190000_the_merge_record_is_written_only_by_the_merge.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype in `C:\w31`: SHA-256 `8286493bc96dd795baea727252acc8a4fcf1e3efa77bea0ffcd1ce6100329c85`, md5 `705b8d7f40c633142f63bc98124a3355`, 8030 bytes.
   - It holds exactly two statements:
     - `revoke insert, update on public.customer_identity_merges from authenticated;`
     - `app.merge_customer_identity` replaced. The new body is SPEC-240's body plus one declared variable and two record refusals placed after the archive refusals: `source customer was already merged into %` and `target customer was merged into %`.
   - If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/144_the_merge_record_is_written_only_by_the_merge_test.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `72bce0402e0f11d3296b53da04d3b4afee8fa2bb84aab867bb172565632d1d06`, `select plan(23);`.
   - Its `-- ATTACK-CLASSES:` line reads `DOOR BUSINESS STATE REPLAY INPUT PRIVILEGE AUTH TENANT OBSERVABILITY CONCURRENCY=N/A`, and its header states the `N/A` reason.
   - Then make two LF edits, each byte-identical to the prototype:
     - `supabase/tests/87_actor_attribution_second_door_test.sql`: the `customer_identity_merges` block's positive control merges through `app.merge_customer_identity` and asserts the owner's attribution; SHA-256 `0671672e35dd54ce9a6f789dc0c2a7a2f07f405b26f8470338b40f860aa7a792`, still `plan(29)`.
     - `scripts/verify_role_journeys.ps1`: two MRG-1 checks after the merge block's idempotency check; SHA-256 `a69f843841e16583c90060f2220539d29b8e030608bc3d3e609eab7e2e7d8278`.
   - If a target carries content other than its `368a881` bytes or its frozen value, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` already contains an `MRG-1` row. If not, apply the prototype's edits, each byte-identical to its frozen value, and nothing else:
   - **Register** (`ec10970d1599dae1d11c4e907464dacf08a9e605b5baa3c3674afe25b129d31d`): a 2026-10-07 Slice-31 freshness entry, with the previous one demoted to `Previously:`; and rows MRG-1 (High) and MRG-2 (Medium), each FIXED by SPEC-244 locally with Primary pending, Cert `🛡`.
   - **Disposition** (`dc2569fc1fbfcf58a50604c9a2ad2483a5d4bdac680af9c6728def2594936628`): a freshness entry, with the previous one demoted; coverage 32 of 78 (13 `AUDITED`, 46 `NOT-RECORDED`); the "All 32" line; and the `customer_identity_merges` row `AUDITED` / `ADVERSARIAL` / SPEC-244 / MRG-1, MRG-2, with its evidence and non-defects.

   If a target carries content other than its `368a881` bytes or its frozen value, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 values:
   - a clean local reset; the focused Tests 144 and 87;
   - pgTAP Pass A, all six HTTP suites, then pgTAP Pass B without reset; smoke and the plan sum;
   - the mutation evidence, the causal negative and the six two-session proofs;
   - the API-contract and map generators;
   - the scope check, `git diff --check` and repository consistency.

   Treat as expected at this boundary only: an undeployed Primary, the expected pre-deploy repository-consistency issues, and the guard self-test CONTROL failures they cause.

   Read a fresh Primary baseline, read-only:
   - the project URL, the full ordered ledger and the absence of the target migration;
   - the function and structural surfaces;
   - the table's ACL and the merge's definition md5;
   - the tenant, customer, merge-record and event counts.

   Record the predicted delta.
5. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 4 and present the Gate-2 package. Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261007190000_the_merge_record_is_written_only_by_the_merge`. If it is absent and deployment is separately authorized:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts, the table ACL and the merge md5.
   - On an exact match, apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row, its stored statement md5 equal to the file's, and no existing target version.
   - Read fresh: the ledger, the function surface and all ten structural surfaces; the table ACL; the merge's definition, security mode, `search_path` and ACL; the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with 453 HTTP assertions last passed on the Step-4 date.
   - Confirm that `supabase/tests` holds 144 files whose literal `plan(N)` values sum to 2638, then set `Suite **144 files / 2638 assertions**`; if either differs, stop.
   - Set Batch 6 coverage to 32 of 78, all thirty-two at `ADVERSARIAL`.
   - Mark MRG-1 and MRG-2 `DEPLOYED` with Cert `✅`.
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
     - set `Last Completed` to SPEC-244 / Slice 31;
     - set `Current Module` to Foundation Completion Programme Batch 6 resuming at Slice 32;
     - set `Next capability` to **Foundation Completion Programme — Batch 6 Slice 32**, naming the measured first target, followed by the Phase-8 order roadmap 32 owns, keeping its closed-chapter and standing-fact sentences;
     - keep the manifest within 7000 characters;
     - regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate with `scripts/publish_candidate.ps1` and require exact-SHA candidate CI.
   - Promote the same accepted SHA, require main CI, and run `-Certify` for `REMOTE_CERTIFY: READY`.
   - Verify synchronized clean refs.

## Acceptance Criteria

- [x] `authenticated` holds SELECT and neither INSERT, UPDATE nor DELETE on `customer_identity_merges`. A MERGE_CUSTOMER_IDENTITY holder at aal2 can neither create nor rewrite a merge record at the table, in pgTAP or over HTTP.
- [x] A customer that was never merged answers only to its own consent decisions. Its call is not claimed on another customer's consent, and it can always record a withdrawal.
- [x] The merge is unchanged for a valid pair. It archives the source, re-points its history, writes one record attributed to the caller at the server's time and emits one critical event.
- [x] The merge refuses a source or a target that the record names as merged away, whatever its archive flag. Its archive, self-merge, privilege, step-up and tenant refusals keep their messages.
- [x] Test 87 proves ATTR-2's merge attribution through the merge.
- [x] Mutants M1 to M4 are each killed, with installation and restoration md5-proven. The causal negative and the six two-session proofs are recorded.
- [x] MRG-1 and MRG-2 are fixed and deployed in the register. `customer_identity_merges` is `AUDITED` / `ADVERSARIAL` in the disposition record, and coverage is 32 of 78. No other surface's row changed; BOOK-11, BOOK-12, PAY-5, CONV-9 and CONV-10 are unchanged.
- [x] The migration, the two tests, the HTTP script and the two Step-3 documents matched their frozen SHA-256 values when applied.
- [x] Primary, the recorded evidence, the manifest (241 migrations; 144 files / 2638 assertions; 453 HTTP assertions), the API contract and `ai-map.json` agree.
- [x] The manifest names Batch 6 Slice 32 and its measured target as the next capability, with no Active Change Request.
- [x] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [x] No file outside Write Scope was created, modified or deleted.

## Execution Log

None.

### 2026-10-07 — Owner-delegated approval and execution start

The owner's Slice-31 directive of 2026-10-07 directed this bounded Batch-6 slice to proceed through repository governance: reproduce, repair only evidence-backed defects, give the surface a truthful disposition, stop once at the exact Primary Gate-2 boundary if a migration is earned, then publish and synchronize. It does not authorize any Primary write; Gate 2 is required.

- Draft `e047151`; a read-only evaluation of it returned `APPROVAL_EVIDENCE: PASS` (profiles DATABASE and REPOSITORY).
- Approved at `4caccda`; its pre-commit Gate reported `APPROVAL_EVIDENCE: PASS`.
- In Progress from this commit. Resume Step 1. Primary stays read-only until Gate 2; Secondary `brplkqmbzffpxqgkkdzo` is never contacted.

### 2026-10-07 — Steps 1-3 applied (uncommitted until after deployment)

- **Step 1: Applied.** The migration was absent. It was created LF and ASCII, byte-identical to the prototype: SHA-256 `8286493bc96dd795baea727252acc8a4fcf1e3efa77bea0ffcd1ce6100329c85`, md5 `705b8d7f40c633142f63bc98124a3355`, 8030 bytes.
- **Step 2: Applied.** Test 144 (`72bce040…`, `plan(23)`), Test 87 (`0671672e…`) and `scripts/verify_role_journeys.ps1` (`a69f8438…`) match their frozen SHA-256 values. Both edited targets held their committed bytes first.
- **Step 3: Applied.** The register held no MRG-1 row. Register `ec10970d…` and disposition `dc2569fc…` match their frozen values; both held their committed bytes first.

Per the DATABASE sequencing, these six paths stay uncommitted until Primary is deployed and the manifest remeasured.

### 2026-10-07 — Pre-deploy readiness gate

Run on HEAD `674236a` with every Step 1-3 file at its frozen hash.

- **Reset:** a clean local reset to 241 migrations, latest `20261007190000`.
- **Focused:** Tests 144 and 87, 52/52 (23 + 29).
- **pgTAP Pass A:** 144 files / 2638 assertions PASS.
- **HTTP suites:** `verify_api_end_to_end` 35, `verify_care_journeys` 40, `verify_journey_branches` 74, `verify_lifecycle_branches` 122, `verify_role_journeys` 122 (the declared suite, including the two MRG-1 checks), `verify_storage_end_to_end` 60: 453 passed, 0 failed.
- **pgTAP Pass B,** without reset: 144 / 2638 PASS.
- **Smoke:** `ALL CHECKS PASSED (78 tables, … 71/622 catalog, …)`. Plan sum: 144 files, 2638 assertions.
- **Mutation:** base surface md5 `eb747464e820ccc17f02e4dabc2d734d` (the merge's definition and the table's ACL). Every installation was proven by a changed md5 and every restoration by the base md5; the final md5 equals the base, and Test 144 passed afterwards. All four were killed, with results identical to the prototype:

  | Mutant | Failing assertions | Ran of 23 |
  | --- | --- | --- |
  | M1 INSERT restored | 1, 3, 4, 5, 6 | 6 |
  | M2 UPDATE restored | 1, 10, 11, 19, 20, 21, 23 | 23 |
  | M3 source record check removed | 19, 20, 21 | 23 |
  | M4 target record check removed | 20, 21, 22 | 23 |

  M1's run stops after its named failures, as the Mutation Obligation admits.
- **HTTP discrimination (prototype):** with INSERT and UPDATE re-granted, `verify_role_journeys.ps1` failed exactly its two MRG-1 checks (POST 201; PATCH 204, record rewritten to `rewritten`/2001) and passed the other 120.
- **Causal negative:** the measurements in Business Reason, taken at `368a881` before the repair.
- **Two-session proofs on the final schema,** each with an observed `pg_blocking_pids` edge:
  - A→B against A→C, and A→B against B→A: one merge, an active survivor, and the loser refused for its own lifecycle reason;
  - a merge against a consent decision on the source, both orders: either the decision is refused toward the survivor, or it lands first and governs both;
  - a merge against a decision on the target, both orders: serialized, and the target's denial governs both.

  `scripts/verify_customer_concurrency.py` passes its three cases.
- **Generators:** `MASTER_API_CONTRACT.md` regenerates with exactly two lines moved: the table's `SIU-` → `S---` and the merge's refusal count 7 → 9 (SHA-256 `d8ef4dc6ae433fe7748d823af057f4e4ce7d64f4ecea12af86a6559829943ef8`). Totals are 80 RPC endpoints (80 with HTTP evidence), 8 views and 74 tables. `ai-map.json` differs only in `generated_at`. Both were restored until Step 7.
- **Scope and diff check:** the six changed paths are all in Write Scope; `git diff --check` exited 0.
- **Repository consistency:** exactly the six expected pre-deploy issues: three migration-state drifts, two suite-figure drifts and RECOVER-1.
- **Guard self-tests (prototype):** future-date 18/0 and status-contradiction 33/0. Primary-ledger and cold-start fail only their clean-repository CONTROL cases. Re-run at Step 7.

**Fresh Primary baseline,** read-only from `https://vrvtsxexkiiiivlkdxzp.supabase.co`:
- **Ledger:** 240 migrations, `5907e3b5a170d153797aff8cb08ca20e`, equal to the recorded evidence; latest `20261007120000`. The target is absent by version and by name.
- **Structural surfaces:** functions `e6bb8dd3…`/320, triggers `d07aa82d…`/306, policies `b67d466a…`/125, constraints `cea733ef…`/525, grants `ebdcfde6…`/195, columns `448db887…`/1134, views `10bb212a…`/16, indexes `56872e87…`/299, status_transitions `db2165c7…`/115, rls_enabled `c117cbf7…`/79. `_combined` is `f8062e9459f894e1f4e0a5b8ef0b0efc`/3114, equal to the recorded evidence.
- **The surface:** table ACL `{postgres=arwdDxtm/postgres,service_role=arwdDxtm/postgres,authenticated=arw/postgres}`; merge definition md5 `375a663c0b700498b78c029c5ce07e15`.
- **Business rows:** 0 tenants, customers, merge records, consents and events.

**Predicted delta,** equal to the local post-migration surface:
- **Ledger:** 241 migrations, latest `20261007190000`, fingerprint `a7f02a08140c6ef7e0ed7a68f52aeeb5`.
- **Functions:** `8eb85701fe0935b6ca60349a6c34ba71`/320 (the merge body replaced).
- **Grants:** `134cce397b6d69b35f1745ea014168e3`/193 (−2: `authenticated` INSERT and UPDATE).
- **Unchanged:** triggers, policies, constraints, columns, views, indexes, status_transitions and rls_enabled.
- **`_combined`:** `235c36872752c174d3fde2ff3a042be2`/3112.
- **Table ACL:** `authenticated=r`. Merge definition md5 `a1534c3eb8af1587f4dc83c7325b1361` locally.
- **Business rows:** none written.

Stopped at Step 5: Human Gate 2.
### 2026-10-08 — Human Gate 2: owner authorization

The owner authorized deployment to Primary `vrvtsxexkiiiivlkdxzp` of exactly `supabase/migrations/20261007190000_the_merge_record_is_written_only_by_the_merge.sql`, SHA-256 `8286493bc96dd795baea727252acc8a4fcf1e3efa77bea0ffcd1ce6100329c85`, md5 `705b8d7f40c633142f63bc98124a3355`, with the focused test `144_the_merge_record_is_written_only_by_the_merge_test.sql` at SHA-256 `72bce0402e0f11d3296b53da04d3b4afee8fa2bb84aab867bb172565632d1d06`.

Conditions, any mismatch voiding it:
- HEAD `6dce92d6a4c075fa5db2d057f03da252bc552d69` or the exact canonical equivalent;
- the hashes unchanged;
- Primary at 240 migrations with latest `20261007120000` and `20261007190000` absent;
- no business rows that invalidate the proof;
- `authenticated` still holding the INSERT and UPDATE being removed;
- Secondary never contacted.

The authorization continues through post-deploy verification, Review, Complete, publication, exact-SHA candidate CI, promotion, `REMOTE_CERTIFY: READY` and synchronization. It ends with the next capability set to the measured Batch 6 Slice 32 target. It does not authorize Slice 32, n8n or any Phase-8 workflow work.

### 2026-10-08 — Step 6: Primary deployment

**Prewrite recheck, every condition exact:**
- HEAD `6dce92d6a4c075fa5db2d057f03da252bc552d69`, with only the six in-scope Step 1-3 paths dirty;
- migration SHA-256 `8286493b…`, md5 `705b8d7f…`, 8030 bytes, 0 CR, 0 non-ASCII; Test 144 `72bce040…`;
- project URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`;
- ledger 240, `5907e3b5…`, latest `20261007120000`, with the target absent by version and name;
- table ACL `authenticated=arw`, INSERT and UPDATE true;
- merge md5 `375a663c…`;
- 0 tenants, customers, merge records, consents and events.

**Write:**
- The text to transmit was first proven server-side, read-only, to hash to md5 `705b8d7f40c633142f63bc98124a3355` and 8030 bytes.
- That text was applied through `apply_migration` as `the_merge_record_is_written_only_by_the_merge`. The connector assigned the temporary version `20261008051505`; its single stored statement has md5 `705b8d7f…` and 8030 bytes, equal to the file.
- One guarded CTE UPDATE renamed only that row to `20261007190000`. The guard required 241 rows, the other 240 hashing to the baseline, the statement md5 to match and no existing target. All four held, and 1 row was renamed.

**Fresh postwrite reads, every value equal to the frozen prediction:**
- **Ledger:** 241, `a7f02a08140c6ef7e0ed7a68f52aeeb5`, latest `20261007190000`, present once; the temporary version is gone.
- **Surfaces:** functions `8eb85701…`/320, triggers `d07aa82d…`/306, policies `b67d466a…`/125, constraints `cea733ef…`/525, grants `134cce39…`/193, columns `448db887…`/1134, views `10bb212a…`/16, indexes `56872e87…`/299, status_transitions `db2165c7…`/115, rls_enabled `c117cbf7…`/79. `_combined` is `235c36872752c174d3fde2ff3a042be2`/3112.
- **Table:** ACL `{postgres=arwdDxtm, service_role=arwdDxtm, authenticated=r}`. `authenticated` holds SELECT and has no INSERT, UPDATE or DELETE. `service_role`'s privileges come from Primary's platform default ACL (PAR-5) and are unchanged. Its three triggers are present.
- **Merge:** `app.merge_customer_identity` md5 `a1534c3eb8af1587f4dc83c7325b1361`, byte-identical to local; SECURITY DEFINER, owner `postgres`, `search_path=""`, ACL `{postgres=X, authenticated=X}` as before and as local. The `public` HTTP wrapper is unchanged.
- **Business rows:** 0 tenants, customers, merge records, consents and events.

**Behaviour on the deployed bytes,** proven locally on the byte-identical function and grant, because no business data is written on Primary:
- The complete ADR-0019 merge: Test 144 assertion 9; Test 111.
- A merged source un-archived and merged again is refused: Test 144 assertion 19.
- A reverse merge into a merged source is refused: Test 144 assertion 20.
- A legitimate survivor chain still merges. Test 142's merge section (assertions 26–37) merges X1 into X2 and then the survivor X2 into X3, and consent follows the chain. Both pass unchanged in Pass A and Pass B.
- `app.customer_consent_status` follows only real lineage: Test 144 assertions 4, 11 and 21–23; Test 142.
- Table DML cannot manufacture lineage, in pgTAP (Test 144 assertions 1, 3 and 10) and over HTTP (`verify_role_journeys.ps1`).
- Test 87 proves the merge's attribution through the merge itself: assertions 19–20.

No business-data write and no reproduction was made on Primary. Secondary `brplkqmbzffpxqgkkdzo` was not contacted.

### 2026-10-08 — Step 7: evidence and measured state

- `reports/evidence/primary-ledger-evidence.json` was rewritten from the fresh readings only: 241 migrations, `a7f02a08…`, functions `8eb85701…`/320, structural `235c3687…`/3112, head `6dce92d`. Its ledger equals Primary's full ordered list and the repository's migration files.
- `supabase/tests` holds 144 files whose `plan(N)` values sum to 2638. The manifest's `Live state` now reads:
  - 241 migrations, latest `20261007190000`, with the same hashes and counts;
  - 78 tables, `71/622` catalog, 80 client RPCs;
  - `Suite **144 files / 2638 assertions**`, and 453 HTTP assertions last passed 2026-10-07.

  Batch 6 coverage reads 32 of 78, all thirty-two at `ADVERSARIAL`. The manifest measures 6736 characters.
- MRG-1 and MRG-2 are marked DEPLOYED with Cert `✅`.
- `MASTER_API_CONTRACT.md` was regenerated (SHA-256 `d8ef4dc6…`, the two predicted lines); `ai-map.json` was regenerated and stored LF.
- The four guard self-tests pass: future-date 18/0, status-contradiction 33/0, primary-ledger 13/0, cold-start 34/0. The first cold-start run failed 9 CONTROL cases on one repository-consistency issue: the two register rows' DEPLOYED text carried 2026-10-08 beneath the register's 2026-10-07 freshness line (Check 21, STALE-1). The date was removed from that phrase, as the ASGN rows word it. `check_primary_ledger.ps1` `RECOVER-1 LEDGER EVIDENCE: CLEAN`; `check_database_parity_evidence.ps1` `PRIMARY PARITY EVIDENCE: CLEAN`; repository consistency exit 0; `git diff --check` exit 0.
- The Runtime Checkpoint is DONE, so Step 8's `-Finish` runs in VERIFY mode.
### 2026-10-08 — Post-deploy local certification

Canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` ran on the clean committed execution HEAD `300f120` in VERIFY mode, with profiles DATABASE and REPOSITORY. It passed every mandatory verification on its first run and returned `LOCAL_CERTIFY: READY`:
- reset; pgTAP Pass A; the declared `verify_role_journeys.ps1`; pgTAP Pass B; smoke;
- `check_database_parity_evidence.ps1`; repository consistency; `git diff --check`; `check_primary_ledger.ps1`.

**Selector after Slice 31** (`scripts/batch6_select_target.ps1`, 46 surfaces still `NOT-RECORDED`), as Exposure/coverage:
1. `journal_entry_lines` 8/26
2. `tenant_license_activations` 8/30
3. `service_requests` 8/34
4. `quotation_items` 8/36
5. `totp_enrollments` 8/38
6. `subscription_payment_proofs` 8/48
7. `complaints` 8/48
8. `payment_allocations` 8/60
9. `receipts` 7/20
10. `chart_of_accounts` 7/32
11. `notification_deliveries` 7/42
12. `journal_entries` 7/46

Slice 32's measured target is `journal_entry_lines`.

## Verification Notes

None.

### 2026-10-08 — Independent Review of execution commit `300f120`

Reviewed the committed tree against the approved Draft `e047151`, the owner's Gate-2 authorization and the frozen eleven-path Write Scope, not against the Execution Log.
- **Scope.** `368a881..300f120` changes eleven paths, all in Write Scope. Every Out-of-Scope file is untouched, among them Tests 10, 53, 57, 58, 71, 111 and 142, ADR-0019, `verify_database.sql` and `verify_customer_concurrency.py`.
- **Frozen bytes.** The committed migration (`8286493b…`), Test 144 (`72bce040…`), Test 87 (`0671672e…`), `verify_role_journeys.ps1` (`a69f8438…`) and the disposition (`dc2569fc…`) hash to their frozen values. The register differs from its Step-3 value only in the two MRG rows' Step-7 `DEPLOYED` status and Cert `✅`.

Acceptance, re-checked against the committed bytes, the certified run and the Primary readback:
1. **No table door.** Test 144 assertions 1, 3 and 10 and the Primary readback (`authenticated=r`; no INSERT, UPDATE or DELETE); `verify_role_journeys.ps1`'s two MRG-1 checks over HTTP. Mutants M1 and M2 are killed.
2. **Own consent only.** Assertions 4–7: A's DENIED governs A, A's call is not claimed on B's consent, A can withdraw, and the call is claimed once A itself grants.
3. **The merge is unchanged for a valid pair.** Assertions 8–9 and Tests 71, 111 and 142, unchanged; the survivor chain of Test 142 still merges.
4. **The record decides.** Assertions 18–23: an un-archived source is not merged again, and a merge back into it is refused. Every other refusal keeps its message (assertions 12–17). Mutants M3 and M4 are killed.
5. **Test 87** proves ATTR-2's attribution through the merge (assertions 19–20).
6. **Mutation and concurrency.** M1–M4 killed with md5-proven install and restore, identical on the prototype and the main checkout. The causal negative and the six two-session proofs are recorded, and `verify_customer_concurrency.py` passes.
7. **Records.** MRG-1 and MRG-2 are fixed and deployed. `customer_identity_merges` is `AUDITED` / `ADVERSARIAL` with coverage 32 of 78. No other surface row changed. BOOK-11, BOOK-12, PAY-5, CONV-9 and CONV-10 are byte-identical to `368a881`.
8. **Frozen values** matched when applied (Steps 1–3 log).
9. **Agreement.** Primary, the evidence and the manifest agree: 241 migrations, `a7f02a08…`, functions `8eb85701…`/320, structural `235c3687…`/3112, 144 files / 2638 assertions, 453 HTTP assertions. The API contract matches its generator, and `ai-map.json` is regenerated. RECOVER-1 and parity evidence are CLEAN, and the four guard self-tests pass.
10. **Handoff.** The Complete commit sets the next capability to Batch 6 Slice 32 at the selector's measured target, with no Active Change Request.
11. **Primary.** Only the authorized bytes (statement md5 `705b8d7f…`) and the one guarded rename; 0 business rows before and after. Secondary was never contacted.
12. **Scope.** No file outside Write Scope was created, modified or deleted.

Not built, as directed: Slice 32, the n8n workflow and any Phase-8 work.

Verdict: Confirmed Complete

Recommendation to human: Set Status to Complete

## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created or deleted.
- [x] No section was added, removed or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

- **EARN IT.** Both findings were reproduced through the real claim, the real consent functions and the HTTP door on the pre-repair schema. The surface was selected by measurement, and nothing outside it is touched.
- **WORTH IT.** One revoke and two reads in an existing function. No new table, trigger, permission, event or structure.
- **SIMPLIFY IT WITHOUT WEAKENING.** The redundant door is removed rather than defended. The merge judges "merged" by the record the consent functions already read, under the locks it already takes.
- **Owner delegation (2026-10-07, Slice-31 directive).** The owner directed this slice to proceed through repository governance to a Primary Gate-2 stop if a migration is earned, then through publication and synchronization. Approving this contract does not authorize any Primary write.
- **Deliberately not changed:** ADR-0019; the customers archive door (CUST-11); the consent functions (SPEC-240); `app.guard_write_capability`'s map and `app.derive_merge_actor`; the n8n workflow, PH8-10, BOOK-11, BOOK-12, PAY-5, CONV-9 and CONV-10; the registered worktrees `owt/p2` and `C:\w234`.
