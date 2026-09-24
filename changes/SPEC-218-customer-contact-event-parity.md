# Change Request — SPEC-218

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
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

Resume Step: 1
Blocker: HUMAN_CR_APPROVAL
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

- [ ] Both authorized INSERT doors emit exactly one customer-scoped contact event per persisted contact, and refused writes emit none.
- [ ] Existing RPC normalization, primary-per-type behavior, actor attribution, authorization and customer merge behavior remain proven.
- [ ] CM-3 is recorded fixed, and `customer_contact_methods` is `AUDITED` / `ADVERSARIAL` with mechanically correct 19/77 coverage.
- [ ] Migration/test identities, generated artifacts, local and fresh Primary evidence match; no unauthorized file changed.

## Execution Log

None yet — Draft awaits human approval.

## Verification Notes

None yet.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

EARN IT: the event discrepancy and its customer-timeline consequence were reproduced on a real authorized row, while the existing permission, tenant, catalog, normalization and uniqueness controls were observed separately. WORTH IT: leaving the discrepancy makes the customer history incomplete; revoking INSERT breaks the SECURITY INVOKER RPC; a generic event framework changes unswept surfaces. One INSERT trigger plus removal of the RPC's duplicate producer is the smallest proven repair. Two rolled-back experiments left no local schema or fixture residue. The observed unused `is_verified` and `created_at` fields do not earn extra policy here.
