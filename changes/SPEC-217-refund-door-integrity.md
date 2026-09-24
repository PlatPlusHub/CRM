# Change Request — SPEC-217

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make the authenticated `public.refunds` table door preserve refund write authority, positive value, entry state and completion time with one refund-local BEFORE trigger.

## Business Reason

Batch 6 Slice 17 selected `refunds` from the live selector: Exposure 11, coverage 34; `customer_contact_methods` was runner-up at Exposure 11, coverage 42. Score is diagnostic. A rolled-back local probe proved an `employee` who could see a completed refund but lacked `RECORD_REFUND` changed its `payment_direction_code` to `supplier_refund`, removing 25,000 EGP from that customer's computed refunded amount. Another probe proved a `finance_manager` holding `RECORD_REFUND` inserted a refund directly as `completed`: it immediately added 7 EGP to `app.customer_balance` with no completion time or event. A direct `requested` row accepted amount zero and a forged 2020 completion time. The creating RPC requires a positive amount and creates only `requested`; the advancing RPC stamps completion time. The selected repair makes those rules hold at the table door while retaining the RPCs and the supplier-refund table path.

## Risks

- Authenticated refund UPDATEs that previously needed only row visibility will now require `RECORD_REFUND` and its MFA check. This is the intended authority: `app.advance_refund` charges it on every transition, and no other `app` or `public` function updates refunds. The direct finance path remains allowed.
- The new trigger runs on every INSERT and UPDATE. The rolled-back prototype admitted `app.record_refund`, two `app.advance_refund` transitions, and a direct supplier refund. The complete local suite and six HTTP suites must still pass before any Primary write.
- Session-less platform writes remain exempt, matching `app.guard_financial_capability` and `app.enforce_status_transition`; tenant users with no resolved identity cannot satisfy the existing RLS policy. Primary currently holds zero refund rows (fresh read, 2026-09-24), and this migration changes no existing row.
- Direct legal status transitions still omit the RPC's event. That is separately reproduced as RFD-3 and remains open: making the table trigger the event producer while preserving `p_reason` needs a separate event-authority change. This repair must not claim event parity.
- Primary deployment is an irreversible action and requires a separate exact owner authorization after all local proof.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-217-refund-door-integrity.md`
- `supabase/migrations/20260924150000_refund_door_integrity.sql`
- `supabase/tests/123_refund_door_integrity_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607047500_record_refund.sql`
- `supabase/migrations/202607047600_advance_refund.sql`
- `supabase/migrations/202607052700_lifecycle_transition_enforcement.sql`
- `supabase/migrations/202607057100_an_invoice_may_not_be_declared_paid_by_anyone_who_can_see_it.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `reports/architecture-decision-records.md`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/25_catalog_registry.md` (`refund_status_code`); `_ORVION_CANONICAL/28_permissions_matrix.md` (`RECORD_REFUND`); `_ORVION_CANONICAL/31_schema_draft.md` (`refunds`)
- `supabase/migrations/202607047500_record_refund.sql`; `supabase/migrations/202607047600_advance_refund.sql`; `supabase/migrations/202607052700_lifecycle_transition_enforcement.sql`; `supabase/migrations/202607057100_an_invoice_may_not_be_declared_paid_by_anyone_who_can_see_it.sql`
- `reports/master/MASTER_GAP_REGISTER.md` (ENTRY-1); `reports/master/MASTER_SURFACE_DISPOSITION.md` (`refunds`)
- `reports/evidence/primary-ledger-evidence.json`; `reports/master/MASTER_INTEGRATION_CATALOG.md` §0

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
| All authenticated refund UPDATEs require `RECORD_REFUND` | `app.advance_refund`; `refunds_enforce_status_transition`; `app.guard_financial_capability` | VERIFY | The RPC already charges `RECORD_REFUND`; prototype completed requested → approved → completed, with three events. The existing status trigger keeps legal transitions; the amount trigger remains unchanged. No other function updates refunds (`scripts/impact.ps1 -Target refunds`, runtime and source search). |
| Refund INSERT starts `requested`, positive and without `completed_at` | `app.record_refund`; direct customer and supplier refund paths | VERIFY | RPC inserts that shape. Prototype accepted its customer refund and a direct `supplier_refund` requested for a real supplier; refused completed entry and zero amount with `23514`. The existing catalog and tenant FK guards remain. |
| Completion time comes from the status transition | `app.advance_refund`; direct authorized transitions; refund listing | VERIFY | The RPC's `now()` and the BEFORE guard's `now()` agree in meaning. Prototype overwrote a supplied 2019 time on direct approved → completed; a later edit retains the original time. |
| `customer_id`, direction, currency and amount become protected against read-authority UPDATE | `app.customer_balance`; `app.customer_exposure_in_limit_currency`; `refunds_probe_customer_credit`; booking issue's balance/risk decision | VERIFY | Before repair, employee direction change moved refunded and outstanding figures by 25,000 EGP; prototype refused the same edit with `42501`. No consumer source changes: it reads the same truthful row. |
| Same table row | `app.customer_timeline`; `public.events.audit_read` | UNAFFECTED | No event producer is changed; RFD-3 records the remaining direct-DML event gap, so this CR does not assert audit parity. |
| Same table row | `refunds.scope_isolation`; tenant-qualified FKs; subscription gate; catalog guard; `derive_created_by`; credit probe; updated-at trigger | VERIFY | Existing RLS, tenant, subscription, vocabulary, attribution and downstream credit checks remain attached. New test checks positive row visibility, foreign tenant refusal, attribution and a successful supplier path. |
| Session-less platform and administrative writes | migrations; `postgres` fixtures; possible hosted `service_role` table grant | VERIFY | Guard returns when `auth.uid()` is NULL, matching the two existing refund guards. The clean reset, suite and HTTP paths exercise the existing system population. No grant changes. |
| New trigger function and test | `10_grant_model_test.sql`; pgTAP; `scripts/verify_database.sql` | VERIFY | Revoke PUBLIC EXECUTE; new pgTAP asserts trigger shape and both doors. Full local certification required before deployment. |
| New migration and test | `MASTER_API_CONTRACT.md`; Primary evidence; manifest; `ai-map.json` | WRITE | The generated API contract is in Write Scope by Check L3; after deployment all measurements come from Primary, then manifest and map are regenerated. |
| Findings RFD-1, RFD-2, RFD-3 and ENTRY-1's refund instance | gap register; refund disposition and Batch 6 coverage | WRITE | Register owns findings; disposition owns the audit state. Check 22 recomputes 18/77 and Check 24 requires a real negative pgTAP assertion. |

Unresolved Material Consumers: None

RFD-3 is an independently owned event-production defect, not an unresolved reader of the changed rule.

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, pgTAP Pass A/B, six HTTP suites, smoke and mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Gap IDs, refund disposition, test attack classes and coverage agree | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Manifest migration figures and Primary ledger match | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite totals match the test plans | AFTER_IRREVERSIBLE_ACTION | Step 2 | Step 7 | Step 8 |
| `ai-map.json` agrees with manifest | BEFORE_COMPLETION | Step 7 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: `app.guard_financial_capability` only charges UPDATE when `amount` changes, so it did not stop the reproduced direction edit; widening its shared mapping changes six surfaces and still does not govern entry state or completion time. `app.enforce_status_transition` only fires on UPDATE when status changes, and cannot guard the INSERT or the status-neutral edit. RLS admits a visible booking under its shared `FOR ALL` policy, and replacing it with `has_permission` alone would lose `app.authorize`'s MFA condition. Revoking UPDATE breaks the SECURITY INVOKER `advance_refund`; a generic ENTRY-1 control changes unswept surfaces. One refund-local BEFORE trigger reuses the established guard shape with the least blast radius.

Added Property: authenticated refund rows begin `requested`, have positive amount and no completion time, every UPDATE costs `RECORD_REFUND` with MFA, and completion time is server-derived and then immutable; session-less paths retain their existing behavior.

Causal Negative: With a real visible completed refund, employee `RECORD_REFUND = false`, UPDATE direction succeeded and customer refunded amount fell 25,000 EGP. With finance `RECORD_REFUND = true`, INSERT `completed` succeeded and added 7 EGP to balance without a completion time or event; INSERT `requested` with amount 0 and `completed_at = 2020-01-01` also succeeded. All probes rolled back.

Positive Test Design: Prove the employee sees the real refund and lacks `RECORD_REFUND`; prove finance has the capability at `aal2`, creates via `app.record_refund`, advances through approved and completed, and retains one event per RPC action; prove finance can create a requested supplier refund and legally complete it directly with a server time; prove session-less fixture creation remains possible.

Negative Test Design: Employee's direction and currency UPDATEs fail `42501` while row visibility and a successful finance UPDATE prove no empty-target false green; finance INSERT completed, INSERT requested with a completion time, INSERT amount 0 and UPDATE amount 0 fail `23514`; `aal1` finance UPDATE fails `42501`; foreign tenant INSERT/UPDATE remains refused by RLS or is invisible.

Non-Empty Population Obligation: All denial targets are counted and visible before attack; after every allowed INSERT/UPDATE the affected row and resulting balance or timestamp are read back. A zero-row UPDATE cannot pass an assertion.

Mutation Obligation: Positively verify installation and the mutated definition/state before each detecting assertion, then restore and prove restoration. Independently remove the entry-state refusal, the UPDATE authorization, the positive-amount refusal and the completion-time assignment; each must turn its targeted negative or positive assertion red. A disabled-trigger probe already proved both completed entry and employee direction edit survive when the guard is absent, with `tgenabled = D` observed, and the savepoint restored `tgenabled = O` and the original function source. Any apply error is RED/INDETERMINATE, never a counted mutant.

Post-Implementation Proof Obligation: The permanent pgTAP file, focused tests, full clean-reset protocol, HTTP suites, mutation kills and local/Primary structural parity must all pass on the final migration bytes. No event-parity claim is made.

## Implementation Steps

1. **Check** that `supabase/migrations/20260924150000_refund_door_integrity.sql` does not exist. If absent, create exactly one migration defining `app.guard_refund_integrity()` as SECURITY INVOKER, `language plpgsql`, `set search_path = ''`, returning trigger. Its first arm returns `NEW` when `(select auth.uid()) is null`. For an authenticated write, reject `NEW.amount <= 0` with `23514`. On INSERT, reject unless `NEW.refund_status_code = 'requested'` and `NEW.completed_at is null`, with `23514`, then return NEW. On UPDATE, call `app.authorize('RECORD_REFUND')` unconditionally; if OLD status differs from `completed` and NEW status equals `completed`, set `NEW.completed_at = now()`, otherwise set `NEW.completed_at = OLD.completed_at`; return NEW. Revoke EXECUTE on this function from PUBLIC. Attach exactly one row-level `BEFORE INSERT OR UPDATE` trigger named `refunds_guard_integrity` on `public.refunds`. Do not alter any existing function, grant, policy, trigger or constraint. If the file exists with different content, stop.

2. **Check** that `supabase/tests/123_refund_door_integrity_test.sql` does not exist. If absent, create a transaction-rolled-back pgTAP file with an `-- ATTACK-CLASSES:` declaration from the closed vocabulary. Build two enterprise tenants, one finance manager and one employee at `aal2`, a visible booking/customer, and a supplier, using the fixture shape in `56_financial_write_capability_test.sql`; establish the employee has no `RECORD_REFUND` and sees a real completed refund. Assert both allowed doors and all denials in the Positive/Negative Test Design, including exact SQLSTATE, non-empty target and changed-row readback; assert `completed_at` is server-derived and survives a later authorized edit; assert the trigger is enabled, BEFORE INSERT OR UPDATE, and the function has no PUBLIC EXECUTE. End with `rollback;`. Declare `plan(N)` equal to the actual assertion count. Do not change existing tests. An existing file with incomplete or different assertions is a STOP.

3. **Check** for `RFD-1` in `reports/master/MASTER_GAP_REGISTER.md`. If absent, add three distinct thirteen-column rows after the existing Slice-16 rows: **RFD-1 (High)**, the employee's unauthorized direction edit and 25,000 EGP customer-balance change, fixed by this guard; **RFD-2 (Low)**, direct zero-amount and forged/missing completion-time records, fixed by this guard; **RFD-3 (Medium, OPEN)**, a legal direct requested → approved → completed path that changed refunded amount by 11 EGP with zero refund events, independently deferred because moving event authority into a trigger without losing the RPC's `p_reason` is a separate change. Keep Owner Decision empty on all three. Append to ENTRY-1 that the `refunds` instance is closed by SPEC-217 and seven surfaces remain; keep the class open. Prepend a dated `Last updated:` entry and preserve history. If any row exists with conflicting semantics, stop.

4. **Check** that the `refunds` disposition still reads `NOT-RECORDED`. If so, set it to `AUDITED-OPEN` / `ADVERSARIAL`, session `SPEC-217-refund-door-integrity`, findings `RFD-1, RFD-2, RFD-3`, and state exactly what was closed, what was proven strong (tenant RLS, catalog, subscription, created-by, legal status UPDATEs, no DELETE), and why RFD-3 remains open. Update the Coverage summary from rows to `18 of 77 recorded · 6 AUDITED · 9 AUDITED-OPEN · 3 PARTIAL · 0 EXEMPT · 59 NOT-RECORDED` and `All 18`; prepend a dated `Last updated:` entry. If the starting disposition or totals differ, stop and reconcile before writing.

5. **Check** for an Execution Log entry headed `Pre-deploy readiness gate`. If absent, run a clean `npx supabase db reset`, pgTAP Pass A, all six Additional Verification suites, pgTAP Pass B, `scripts/verify_database.sql`, generated API contract, focused mutation proof with positive application/restore verification, the suite-plan total, `git diff --check`, migration-set comparison, `scripts/check_repository_consistency.ps1` and all applicable cheap checks. Record measured counts, hashes and exits in that entry. Do not proceed while a product/test failure remains. Only expected undeployed ledger/manifest drift may remain before Step 6; classify each red precisely. Do not weaken a guard or gate.

6. **Check** that Primary's ledger does not already contain `20260924150000_refund_door_integrity`. If absent, stop until the owner explicitly authorizes deploying this exact migration to Primary `vrvtsxexkiiiivlkdxzp` after Step 5, with HEAD, migration/test SHA-256, suite totals, mutation results and expected Primary baseline presented. After authorization, re-confirm project ref, HEAD, migration hash, the 223-entry ledger with fingerprint `6b346033368ea9439a1119a5af5d3fc2` and zero refund rows from fresh Primary reads; any mismatch invalidates authorization. Apply only this migration. If the connector assigned a different version, normalize only its newly created ledger row to `20260924150000`. Re-read the full ledger, function surface, all ten structural surfaces, exact new object definitions and privileges from Primary; prove local/Primary definition and ledger parity. Never contact Secondary.

7. **Check** that Primary evidence already contains `20260924150000_refund_door_integrity`. After Step 6, rewrite `reports/evidence/primary-ledger-evidence.json` solely from fresh Primary readings, then remeasure and update the manifest's live counts/hashes, coverage 18 of 77, Last Completed SPEC-217 and Next capability Batch 6 Slice 18. Regenerate `reports/master/MASTER_API_CONTRACT.md` by its generator and `ai-map.json` by its generator, preserving the repository's line-ending policy. Repeat generation after any manifest-changing lifecycle commit. If Primary was not proven, stop.

8. **Check** for an Execution Log entry headed `Post-deploy verification`. If absent, run Primary-ledger, parity-evidence, repository consistency and generated-artifact checks, record every result and resolve only in-scope discrepancies. Run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`. Independently review every Acceptance Criterion and Review Gate item, append `Verdict: Confirmed Complete` only when earned, set Runtime Checkpoint to DONE, then transition to Complete and clear the manifest pointer. Publish by the canonical candidate mechanism; require exact-SHA CI green, promote only the accepted SHA and require `REMOTE_CERTIFY: READY`, clean tree and all three refs synchronized. Remove only Slice-17 scratch artifacts. Do not begin Slice 18.

## Acceptance Criteria

- [ ] One refund-only trigger guards authenticated INSERT and UPDATE as Step 1 states, with no change to the existing refund RPCs, grants, policies or triggers.
- [ ] The permanent pgTAP file proves positive and negative paths with real rows and exact failures; every declared assertion executes and the stated mutants are positively installed, killed and restored.
- [ ] RFD-1 and RFD-2 are fixed; RFD-3 remains explicitly open; ENTRY-1 records the refund instance closure without promoting a generic rule.
- [ ] `refunds` is `AUDITED-OPEN` / `ADVERSARIAL`, and the disposition authority and manifest both report 18 of 77.
- [ ] Repository, local and Primary migration ledgers and structural/function surfaces match the fresh Primary evidence; generated artifacts match their sources.
- [ ] No file outside Write Scope has changed and all scratch data was rolled back or removed.

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

Selection and evidence were measured at HEAD `ef7955662f46f05ca334dbdd84a5892974c55f25`, local 223 migrations and Primary 223 / latest `20260924140000` / ledger fingerprint `6b346033368ea9439a1119a5af5d3fc2`. Primary project identity was read directly and has zero refund rows. Every prototype and attack used a local transaction ending in ROLLBACK. The installed prototype completed the normal RPC path with three events, allowed a direct supplier refund and stamped completion, refused completed entry and zero amount with `23514`, and refused the employee's direction edit with `42501`. The disabled-trigger mutation was positively verified by `pg_trigger.tgenabled = 'D'`, made both attacks succeed, and was restored inside the savepoint to `tgenabled = 'O'` with the original function source. The full suite has not yet been run against a migration because this is a Draft with no implementation write authority.

WORTH IT: doing nothing leaves a proven unauthorized 25,000 EGP balance change. Widening the shared six-table financial guard solves only that edit and increases blast radius; a status-machine or RLS-only rule solves only part of the evidence and can miss MFA. Revoking UPDATE breaks the SECURITY INVOKER RPC. A generic ENTRY-1 mechanism changes unswept tables. The refund-local trigger preserves both customer and supplier refund paths and adds no new policy vocabulary. Event parity is a distinct authority change and remains RFD-3.
