# Change Request — SPEC-218

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Make each successful customer contact-method INSERT produce exactly one `customer_contact_added` event through either authorized write door.

## Business Reason

Batch 6 Slice 18 selected `customer_contact_methods` live (Exposure 11, coverage 42; `conversations` runner-up at 11/66; 18/77 already dispositioned). An `employee` holding CREATE_CUSTOMER inserted a contact method directly: the row persisted, but `public.events` held zero `customer_contact_added` events. The same actor's RPC insert emitted one. `app.customer_timeline` reads events for the customer, so the direct addition disappears from the customer's history. This is CM-3, a reproduced observability gap.

## Risks

- The AFTER INSERT trigger will emit for all successful inserts, including session-less fixtures; `app.record_event` already supports a null actor for those. The full local protocol must prove no unexpected event-count consumer breaks.
- Replacing the SECURITY INVOKER RPC's event block must preserve authorization, normalization, primary-per-type demotion, insertion, return value, signature, grants and search path. A transaction-scoped prototype proved direct and RPC inserts yielded exactly one event each.
- Primary deployment changes production function and trigger definitions and requires separate owner authorization for exact migration bytes after local proof.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-218-customer-contact-event-parity.md`
- `supabase/migrations/20260924160000_customer_contact_event_parity.sql`
- `supabase/tests/124_customer_contact_event_parity_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607058300_a_primary_is_per_channel_and_a_placement_is_not_over_yet.sql`
- `supabase/migrations/20260909114354_customers_slice11_closure.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `reports/architecture-decision-records.md`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/27_event_catalog.md` (`customer_contact_added`); `_ORVION_CANONICAL/28_permissions_matrix.md` (`CREATE_CUSTOMER`); `_ORVION_CANONICAL/31_schema_draft.md` (`customer_contact_methods`)
- `supabase/migrations/202607058300_a_primary_is_per_channel_and_a_placement_is_not_over_yet.sql`; current local `app.add_customer_contact_method` and `app.record_event` definitions
- `reports/master/MASTER_GAP_REGISTER.md` (CM-1/CM-2); `reports/master/MASTER_SURFACE_DISPOSITION.md` (`customer_contact_methods`)
- `reports/master/MASTER_INTEGRATION_CATALOG.md` §0; `reports/evidence/primary-ledger-evidence.json`

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

- `pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1`
- `pwsh -NoProfile -File scripts/verify_role_journeys.ps1`
- `pwsh -NoProfile -File scripts/verify_care_journeys.ps1`
- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_storage_end_to_end.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Event moves from the RPC body to the successful table INSERT | `app.customer_timeline`; `public.events` | VERIFY | Before: direct INSERT 0 events, RPC 1. `customer_timeline` selects customer events. Rolled-back prototype: after direct INSERT timeline count 1; after RPC INSERT count 2 for two distinct contact IDs. |
| RPC event production changes location | `app.add_customer_contact_method`; HTTP RPC client | VERIFY | Prototype retained the same signature and removed only its event block; the RPC returned a new UUID and emitted exactly one event via the trigger. Final test must prove normalized value, per-type primary behavior and returned ID. |
| Successful direct INSERT now produces an event | `app.guard_write_capability`, tenant RLS, catalog, subscription gate, normalization and uniqueness | VERIFY | These BEFORE controls remain intact; AFTER fires only after successful row write. Test authorized positive and unauthorized/invalid negatives with nonempty fixtures and exact SQLSTATE. |
| Customer merge updates/deletes contact rows | `app.merge_customer_identity` | UNAFFECTED | The new trigger is INSERT only; the merge performs DELETE and UPDATE on this table. Existing merge tests remain mandatory. |
| Session-less, batch and administrative inserts | migrations, pgTAP fixtures, possible service paths | VERIFY | `app.record_event` accepts null actor for a session-less write. Full clean reset, pgTAP and HTTP passes exercise this class. No grant or RLS change. |
| New migration/test and measured state | API contract, Primary evidence, manifest, map, gap register and disposition | WRITE | Generated API contract is in Write Scope; Primary values are read fresh after deployment; CM-3 and 19/77 disposition are synchronized only after proof. |

Unresolved Material Consumers: None

The observed `is_verified=true` and caller-authored `created_at` on direct INSERT have no current function/view/policy reader (fresh local catalog query). No verification workflow or timestamp consumer is established, so this CR does not invent either rule.

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 5 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Local reset, focused test, pgTAP A/B, six HTTP suites, smoke and mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| CM-3 and adversarial disposition agree with test evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest and Primary ledger/structure agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 6 | Step 7 |
| Manifest suite totals agree with actual plans | AFTER_IRREVERSIBLE_ACTION | Step 2 | Step 6 | Step 7 |
| Map and API contract match generators | BEFORE_COMPLETION | Step 6 | Step 6 | Step 7 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: `app.add_customer_contact_method` emits only when called through the RPC. Authenticated direct INSERT must remain granted because that RPC is SECURITY INVOKER. RLS and the capability trigger authorize writes but do not emit events. `app.record_event` is reused as the event authority; no new event framework is needed.

Added Property: every successful INSERT through either door creates one customer-scoped `customer_contact_added` event with the actual contact ID, type and caller actor when present; refused writes create none.

Causal Negative: A rolled-back local transaction created a real enterprise tenant/customer and an employee with CREATE_CUSTOMER; the parent was visible. Direct INSERT persisted a row but produced 0 events; the same actor's RPC INSERT produced 1. The event-only timeline omits the direct row.

Positive Test Design: Prove authorized direct INSERT and RPC INSERT each persist a distinct contact and yield exactly one matching event/timeline entry; preserve normalized value, primary-per-type demotion, caller actor and null-actor system fixture.

Negative Test Design: A trainee who can see the customer but lacks CREATE_CUSTOMER must receive `42501` on direct INSERT with no new event; a denormalized value must receive `23514` with no event; duplicate value must receive `23505` with no event. Verify event count after each denial.

Non-Empty Population Obligation: Count the visible customer and actual inserted contact IDs, prove employee capability and trainee lack of it, then count events by each returned contact ID. No zero-row operation can satisfy the event assertions.

Mutation Obligation: Positively disable the new event trigger and observe direct insertion persist with zero matching events; restore and prove enabled state. Independently restore the RPC event call while the trigger is enabled and observe a duplicate RPC event, then restore exact function source. Mutation apply failures are harness errors, not kills.

Post-Implementation Proof Obligation: Permanent focused pgTAP, two full passes, six HTTP suites, smoke, mutation proof, generated artifacts and local/Primary parity must pass on final bytes.

## Implementation Steps

1. **Check** that `supabase/migrations/20260924160000_customer_contact_event_parity.sql` is absent. If absent, create exactly one migration. Replace `app.add_customer_contact_method(uuid,text,text,boolean)` using its current complete definition, removing only its `perform app.record_event(...)` block and preserving all other semantics, signature, SECURITY INVOKER, `search_path=''` and authenticated EXECUTE. Add one `app.emit_customer_contact_added()` SECURITY INVOKER trigger function with `search_path=''`, returning NEW after calling existing `app.record_event` with `NEW.tenant_id`, `customer_contact_added`, `customer`, `NEW.customer_id`, the session's matching `public.users.id` or null, and the existing JSON payload keys/contact values. Revoke PUBLIC EXECUTE on that trigger function. Attach exactly one row-level AFTER INSERT trigger named `customer_contact_methods_emit_added_event` on `public.customer_contact_methods`. Do not alter other functions, grants, policies, triggers or constraints. If the target file exists with different bytes, stop.
2. **Check** that `supabase/tests/124_customer_contact_event_parity_test.sql` is absent. If absent, create a transaction-rolled-back pgTAP file with `-- ATTACK-CLASSES:` from the closed vocabulary. Exercise the Positive/Negative Test Design with exact event counts and IDs; prove the trigger is enabled and AFTER INSERT; prove no direct EXECUTE grant on its function; retain real non-empty controls and `plan(N)` matching executed assertions. Do not modify existing tests. If an existing file differs, stop.
3. **Check** whether CM-3 exists in `reports/master/MASTER_GAP_REGISTER.md` and whether the `customer_contact_methods` disposition is still NOT-RECORDED. If absent and unchanged, add one CM-3 finding (Low, fixed by this migration) with actor, operation, actual result, timeline consequence and proof; prepend the dated update without rewriting history. Set only this surface to `AUDITED` / `ADVERSARIAL`, session `SPEC-218-customer-contact-event-parity`, findings `CM-3`, and record which controls held. Recompute coverage mechanically as 19/77 and update the dated disposition summary. If prior state conflicts, stop and reconcile.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run a clean local DB reset, focused pgTAP, pgTAP Pass A, six declared HTTP suites, pgTAP Pass B without reset, `verify_database.sql`, mutation proof with observed trigger/function state and restoration, plan sum, API-contract generator, `git diff --check`, repository consistency and applicable parity readiness. Record exact counts, hashes, exits and expected undeployed-only reds. Do not ask for Primary authorization until all local evidence is complete.
5. **Check** that Primary lacks `20260924160000_customer_contact_event_parity`. If absent, require the owner's separate authorization of exact migration and test hashes on Primary `vrvtsxexkiiiivlkdxzp`. Immediately before write re-read target, HEAD, hashes, full Primary ledger, migration absence and customer-contact row count; any mismatch invalidates authorization. Apply only the authorized migration; if the connector assigns a temporary version, normalize only its newly inserted row. Read the ordered ledger, function and all ten structural surfaces, changed definitions and privileges fresh from Primary; never contact Secondary.
6. **Check** that fresh Primary evidence includes the new migration identity. If so, rewrite `reports/evidence/primary-ledger-evidence.json` only from Primary reads; update the manifest's measured migration/function/structure and test totals, coverage 19/77, Last Completed SPEC-218 and Next Capability Slice 19 without starting it. Regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` by their generators. Run ledger, parity-evidence and repository consistency checks. If Primary is not proven, stop.
7. **Check** for a `Post-deploy verification` Execution Log entry. If absent, run canonical `-Finish` and require `LOCAL_CERTIFY: READY`; record results. Review actual committed scope and every criterion; only after a Confirmed Complete verdict set Runtime Checkpoint DONE, transition Complete and clear the manifest active pointer. Publish through `publish_candidate.ps1`, require exact-SHA CI, promote the same accepted SHA to `main`, require `REMOTE_CERTIFY: READY` and synchronized clean refs. Remove Slice 18 scratch artifacts. Do not begin Slice 19.

## Acceptance Criteria

- [x] Both authorized INSERT doors emit exactly one customer-scoped contact event per persisted contact, and refused writes emit none.
- [x] Existing RPC normalization, primary-per-type behavior, actor attribution, authorization and customer merge behavior remain proven.
- [x] CM-3 is recorded fixed, and `customer_contact_methods` is `AUDITED` / `ADVERSARIAL` with mechanically correct 19/77 coverage.
- [x] Migration/test identities, generated artifacts, local and fresh Primary evidence match; no unauthorized file changed.

## Execution Log

None yet — Draft awaits human approval.

### 2026-09-24 — Owner approval

Outcome: Owner approved the exact Draft SHA `ad26396ea746c4a853da939bcc2ebc53d644cb28`, Objective and nine-path Write Scope, with explicit customer-contact event semantics. Primary deployment is separately gated and is not authorized by this approval.

### 2026-09-24 — Steps 1–3: contact event parity materialized

Outcome: One LF migration (`20260924160000_customer_contact_event_parity.sql`) replaces only the RPC's explicit event block, adds one SECURITY INVOKER AFTER INSERT event function with PUBLIC EXECUTE revoked, and attaches one enabled trigger. A byte-normalized comparison with the prior RPC migration confirms its new function definition differs only by removal of that event block. No grant, RLS policy, UPDATE event, shared framework or adjacent function changed. One LF pgTAP file (`124_...`) contains 28 non-vacuous assertions. CM-3 is recorded as Low/fixed and the selected surface as AUDITED / ADVERSARIAL; the disposition summary is 19/77. The migration and test files contain zero CR bytes. The focused migration plus test passed 28/28 inside a transaction and left zero trigger residue.

### 2026-09-24 — Pre-deploy readiness gate (Step 4)

Outcome: Local proof is complete; Step 5 waits for the owner's separate exact Primary authorization. No Primary write occurred. Secondary was not contacted.

- Clean `npx supabase db reset`: exit 0, 225 local migrations, latest `20260924160000_customer_contact_event_parity`, ordered ledger fingerprint `843250602025735f48e8c860ea12557f`. Local file and ledger identities match (parity Check L1). Existing HTTP fixtures were reset.
- pgTAP Pass A: 124 files / 2106 assertions, all passed. The six HTTP suites in declared order passed 33 + 120 + 40 + 74 + 122 + 60 = 449 assertions, zero failures. pgTAP Pass B ran without reset and passed the same 124 files / 2106 assertions. Literal `plan(N)` sum also measured 124 / 2106. `scripts/verify_database.sql` exited 0 with `ALL CHECKS PASSED` (77 tables, RLS/policies, 71/621 catalog, FK, grants, append-only audit).
- Permanent focused test on the migrated local stack passed 28/28. Trigger mutant: original `tgenabled=O`; disable applied and observed `D`; authorized direct INSERT persisted one row and emitted zero matching events, while an enabled baseline persisted one and emitted one. Trigger restored and observed `O`, including after rollback. RPC mutant: original `pg_proc.prosrc` MD5 `2763e394a3a841fb244fd3476b434b02` with no RPC event call; installed source MD5 `f64c37ef996adbf690ee6cd89bcb716a` with the call; a real RPC INSERT persisted one row and emitted two matching events. Rollback restored exact original MD5 and removed the call. Every mutation apply and restore returned exit 0; no mutant was inferred from an apply failure.
- Generated `MASTER_API_CONTRACT.md`: 79 RPC endpoints, 8 views, 73 tables, byte-identical to Git. `git diff --check` passed. New SQL files are LF. The only implementation/report changes are in the approved Write Scope.
- Local function surface 304 / `f7acd08a065f71038bb570f131971f03`; structural surface 3042 / `2af308fab1c55f2fe3f984ca2d0ae655`. Compared with a fresh Primary read, delta is +1 function and +1 trigger, with the existing RPC definition replaced; all eight other structural categories retain their Primary hash/count. The new RPC is SECURITY INVOKER, `search_path=''`, source MD5 `2763e394a3a841fb244fd3476b434b02`. The new emitter is SECURITY INVOKER, `search_path=''`, source MD5 `0d553daf881f8ad5c4c9eca0fa5c185b`; the enabled AFTER INSERT row trigger has `tgtype=5`.
- Fresh read-only Primary `vrvtsxexkiiiivlkdxzp`: project ORVION / ACTIVE_HEALTHY / PostgreSQL 17; full ordered ledger 224, latest `20260924150000_refund_door_integrity`, fingerprint `9526e5cf461c7e9fa72d83ade08afa54`. Repo has exactly one additional identity (`20260924160000_customer_contact_event_parity`) and no Primary-only identity; target migration is absent. Primary contact-method row count is zero. Fresh Primary function surface is 303 / `dc9b784927aacedc4e4b46225866633e`; structural surface 3040 / `5fd7e60510aec6059ed9b2aadaeadc9a`, including all ten category hashes. These match the prior recorded Primary baseline, but this entry relies on the new live reads.
- `check_database_parity.ps1` exits 1 because Primary arguments are deliberately absent and the manifest still publishes its 224-migration/303-function/3040-object state; its local L1 and API contract checks passed. `check_primary_ledger.ps1` exits 1 solely because the repository's one new migration is undeployed. `check_repository_consistency.ps1` exits 1 with six expected undeployed items only: migration count/latest/fingerprint, test-file/assertion totals, and RECOVER-1 ledger evidence. Check 22 validates all 77 disposition rows and Check 24 validates all 19 adversarial rows. No guard or invariant was weakened to turn these expected pre-deploy reds green.
- Frozen file hashes: migration SHA-256 `1c77d775b39afc086e01f46470d0bb562c177ce35673c575e651cd38dba3e76b` (3805 bytes); permanent test SHA-256 `17c24c0af4eef46ee6f2c0f1570f38bd54a323afa1ee771f7f4d0477ab348e53` (10218 bytes). HEAD before Primary authorization is the approved-state commit `6b9cc94b233e823efe31cb6e8868cd773be29f5b`; implementation remains an in-scope worktree change because the pre-commit Gate correctly refuses the intentionally undeployed migration.

Blocker: Step 5 requires separate owner authorization for this exact migration SHA-256 and test SHA-256 on Primary `vrvtsxexkiiiivlkdxzp`. Immediately before any write, recheck exact target, HEAD, file hashes, full ledger, target absence and contact-method data precondition. Do not contact Secondary.

### 2026-09-24 — Step 5: exact Primary authorization received

Outcome: Owner authorized Primary `vrvtsxexkiiiivlkdxzp` only, at HEAD `6b9cc94b233e823efe31cb6e8868cd773be29f5b`, for migration `20260924160000_customer_contact_event_parity.sql` SHA-256 `1c77d775b39afc086e01f46470d0bb562c177ce35673c575e651cd38dba3e76b` and permanent test `124_customer_contact_event_parity_test.sql` SHA-256 `17c24c0af4eef46ee6f2c0f1570f38bd54a323afa1ee771f7f4d0477ab348e53`. Authorization requires a fresh exact-target, HEAD, hash, complete-ledger and zero-row check immediately before the sole migration write. It permits normalization only of the newly inserted migration-ledger row if the connector assigns a temporary version. Secondary remains forbidden.

### 2026-09-24 — Steps 5–6: Primary deployment and fresh parity

Outcome: Immediately before the sole Primary write, the live project identified as ORVION / `vrvtsxexkiiiivlkdxzp` / ACTIVE_HEALTHY, HEAD and both authorized SQL hashes matched, the complete ordered Primary ledger was 224 / `9526e5cf461c7e9fa72d83ade08afa54`, latest `20260924150000`, target absent, repository exactly one migration ahead, and `customer_contact_methods` held zero rows. The connector applied only `customer_contact_event_parity` and returned success. It assigned `20260924173622`; a guarded update normalized only that newly inserted row to `20260924160000`. Secondary was not contacted; no production business DML was performed.

Fresh Primary reads after normalization: complete ledger 225 / `843250602025735f48e8c860ea12557f`, latest `20260924160000`, identical to repository and local; function surface 304 / `f7acd08a065f71038bb570f131971f03`; structural surface 3,042 / `2af308fab1c55f2fe3f984ca2d0ae655`. All ten category hashes and counts matched the local clean reset. Direct definition inspection found exactly one `app.emit_customer_contact_added()` (source MD5 `0d553daf881f8ad5c4c9eca0fa5c185b`), SECURITY INVOKER, `search_path=''`, no PUBLIC or authenticated direct EXECUTE; one enabled row-level AFTER INSERT trigger (`tgtype=5`) on `public.customer_contact_methods`. The RPC retained its signature, authenticated EXECUTE and non-event logic, source MD5 `2763e394a3a841fb244fd3476b434b02`, with no explicit event call. The emitter targets `NEW.customer_id`, derives the actor from the matching session user, and carries the contact ID/type payload. Other existing table triggers remain enabled, and no other function source contains `customer_contact_added`. Exact installed-definition parity with the previously behavior-tested local stack avoids production business DML.

The fresh Primary ledger and hashes were written to `reports/evidence/primary-ledger-evidence.json`; manifest figures now state 225 migrations, 304 functions, 3,042 structural objects, 124 pgTAP files / 2,106 assertions, and 19/77 adversarial surfaces. The API contract and ai-map generators ran. `check_primary_ledger.ps1`, `check_database_parity_evidence.ps1`, and `check_repository_consistency.ps1` all exited 0. Awaiting canonical `-Finish`, Review and completion.

### 2026-09-24 — Step 7: local certification and completion

Outcome: `-Finish` exited 0 with `LOCAL_CERTIFY: READY`: clean local reset, both 124-file / 2,106-assertion pgTAP passes, six HTTP suites, database smoke, Primary parity evidence, repository consistency, scope and Git checks passed. Independent Review of committed implementation `70e28ac29176fa014f881f8bf1be15712274932f` recorded `Verdict: Confirmed Complete` in the separate Review commit `ce8e7b208cfbffb3f64d3f3bd487835f86cea764`; every acceptance and Review Gate item is checked. No new architecture decision was introduced. Closing SPEC-218 and clearing the manifest pointer; exact-SHA candidate/CI/promotion remain post-commit publication obligations.

## Verification Notes

None yet.

### 2026-09-24 — Independent Review

Verdict: Confirmed Complete.

Reviewed committed implementation `70e28ac29176fa014f881f8bf1be15712274932f` against the frozen Objective, nine-path Write Scope, Implementation Steps, acceptance criteria and live Primary definitions. The eight changed paths are all scoped; the generated API contract is byte-identical to the local database and needed no change. The single migration and test retain the exact owner-authorized SHA-256 identities. The new pgTAP test proves both real authorized doors produce one event each, a customer timeline entry, correct owner/actor/contact payload and server time, while denied and duplicate paths produce none; it also proves normalization, per-channel primary handling, and no direct authenticated emitter EXECUTE. Existing full-suite customer merge tests passed in both 124-file / 2,106-assertion pgTAP passes. The two installed mutation probes positively established zero direct events with the trigger disabled and two RPC events with the old explicit event call restored; both mutants were rolled back and exact installed definitions rechecked. Six HTTP suites passed 449 assertions. Fresh Primary full ledger, function and all ten structural surfaces matched local after deployment; no production business DML or Secondary access was used. `-Finish` exited 0 and issued `LOCAL_CERTIFY: READY`. `check_primary_ledger`, parity evidence, repository consistency, and `git diff --check` passed. There was no new architecture decision or unresolved blocker. The committed worktree was clean at Review.

Verdict: Confirmed Complete

## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created, or deleted.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

EARN IT: the event discrepancy and its customer-timeline consequence were reproduced on a real authorized row, while the existing permission, tenant, catalog, normalization and uniqueness controls were observed separately. WORTH IT: leaving the discrepancy makes the customer history incomplete; revoking INSERT breaks the SECURITY INVOKER RPC; a generic event framework changes unswept surfaces. One INSERT trigger plus removal of the RPC's duplicate producer is the smallest proven repair. All probes used ROLLBACK and left no local schema or fixture residue. The observed unused `is_verified` and `created_at` fields do not earn extra policy here.

Pre-approval mutation proof on the local database: with the prototype trigger enabled, a direct authorized INSERT persisted and emitted one event. The trigger was positively observed as `tgenabled = D` after disabling it; the next authorized INSERT persisted but emitted zero matching events. Re-enabling was positively observed as `tgenabled = O`. With the original RPC event block still present alongside the trigger, one RPC INSERT emitted two matching events. The transaction rolled back and the probe trigger count returned to zero. A separate rolled-back prototype removed only the RPC event block, after which direct and RPC INSERTs produced one event each, with two distinct contact IDs. A session-less direct INSERT produced one event with null actor, and revoking PUBLIC EXECUTE on the trigger function did not prevent trigger execution. Permanent mutation proof remains an implementation obligation.
