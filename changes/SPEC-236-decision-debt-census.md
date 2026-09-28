# Change Request — SPEC-236

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make repository truth honest before the Phase-8 activation work, without implementing any of it:

- write ADR-0029 (A3) and reconcile `MASTER_ARCHITECTURE_DECISIONS.md` item 11; record `payments.account_amount numeric(18,4)` as the unexplained divergence MONEY-3 rather than an exception;
- implement both halves of SYSADMIN-1 (canon 28 and a permanent assertion);
- record the owner's PH8-4 decision (2026-09-28) and its consent boundary;
- record PH8-9 as a current activation blocker, with Google's current Data Manager contract as build-spec corrections 9–11;
- close PH8-6 by derivation;
- record CTRL-3, the net allocation check's blind spot measured during SPEC-233's publication;
- state the verified state and trigger of the decided-but-unbuilt OWNER-1 items;
- correct the claim "ORVION-side COMPLETE";
- make **Phase-8 Activation Closure** the next capability, with Batch 6 Slice 31 paused until it closes.

## Business Reason

- **The programme.**
  - The owner directed on 2026-09-28 that the Phase-8 activation conditions are a gate to close now, not work to record and postpone.
  - The manifest still names Batch 6 Slice 31 as the next capability.
  - The integration catalog still says "ORVION-side COMPLETE", while:
    - legal table doors skip three conversion source events (CONV-8, BOOK-10, PAY-3);
    - `qualified_phone_call` has no producer (PH8-4);
    - ORVION acknowledges a delivery at ingestion (PH8-9);
    - no delivery workflow exists.
- **Owed and cheap, so fixed here.**
  - **A3:** the owner asked for a small money-storage ADR on 2026-09-01. None exists, and `MASTER_ARCHITECTURE_DECISIONS.md` item 11 still reads "Open owner/ADR-process decision (A3)".
  - **SYSADMIN-1:** the owner asked that the role be documented as reserved and asserted to hold none. `role_permissions` holds 0 rows for it, but no test asserts that, and canon 28's `Optional` cells invite the grant the owner ruled out.
- **MONEY-3 (Low; unexplained, not ratified).**
  - `payments.account_amount` is `numeric(18,4)`. The other 22 stored amounts are `numeric(19,4)`, including `payments.amount` beside it.
  - FA-2's migration documents constrained-type reasoning only for the exchange rate, so the divergence is unexplained.
  - Scale 4 is kept and nothing truncates. The only effect is `22003` at 10^14 or more.
  - Not worth a migration alone: it is widened by the next migration that alters `payments`.
- **PH8-4 (owner decision, 2026-09-28).**
  - A qualification on a lead whose immutable first-touch `lead_source_code` is `google_ads_call` is `qualified_phone_call`, instead of `qualified_lead`, never both.
  - Delivery uses `eventSource = PHONE` and the hashed E.164 phone. No click is required; Google accepts a click id or `userData`.
  - Delivery is fail-closed on `ad_user_data = granted` from ORVION's consent authority, and a call is never itself consent.
  - Whether verbal consent captured on a call is legally sufficient is a counsel question, and it does not prevent the fail-closed mechanism.
  - The smallest consent representation is AUDIT-4's first slice.
- **PH8-9 (current activation blocker; not disproved).**
  - The Data Manager contract is asynchronous: `requestStatus.retrieve` reports `SUCCESS`, `PARTIAL_SUCCESS` or `FAILED` 30 minutes to 24 hours after ingestion, counted per reason and never per record.
  - ORVION marks a delivery `sent` at ingestion and never reclaims it.
  - The derived v1 is one conversion event per ingestion request, which Google's limits allow at about 1,900 deliveries a day even at the worst-case diagnostics cadence.
  - `eventSource` is required, and each event must be routed to its own conversion action.
- **Derived and closed: PH8-6.** Canon 21 requires every send attempt to be recorded, and each claim already inserts its own attempt row. The two unproduced events would duplicate that ledger.
- **CTRL-3 (Low, recorded).** During SPEC-233's publication, `-Gate -BaseRef origin/main` refused a range as `SPEC_ID_NOT_NEXT:234:236`.
  - The per-commit walk saw identifiers retired earlier in the same unpublished range; the net check against the base ref could not.
  - The refusal was fail-closed and was recovered by an owner-authorized rewrite of unpublished history.
  - It is recorded with a recurrence trigger and not repaired.
- **Decided, still owed, each given its trigger or placed in the closure** (verified 2026-09-28):
  - PH8-2/DELIV-1: no health surface exists.
  - PH8-3: there is no default country, and `app.normalize_phone` strips punctuation only.
  - AUTH-1: both tables still exist with zero consumers.
  - RET-2: no export window and no purge.
  - AUDIT-4: no consent table.
  - SPP-3: no platform-operator identity reaches the review path.

## Risks

- **Register and manifest edits could trip the governance checks.** Mitigated: the exact edits were prototyped in a scratch worktree at the published HEAD `23629c1`. `check_repository_consistency.ps1` returned `REPOSITORY CONSISTENCY: CLEAN`: Checks 11, 14, 16 and 25 agree that the open-decision line stays MAIL-1 and RET-1, with PH8-4 settled. `git diff --check` was clean, and the manifest measured 6782 of 7000 characters.
- **A new pgTAP file enters the suite.** It is read-only over the seed, and its counterfactual (granting the role one permission) fails exactly its two decisive assertions.
- **No migration and no Primary write.** Every Phase-8 repair is delivered by its own contract inside the Activation Closure.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-236-decision-debt-census.md`
- `supabase/tests/138_reserved_role_holds_no_permission_test.sql`
- `reports/architecture-decision-records.md`
- `reports/master/MASTER_ARCHITECTURE_DECISIONS.md`
- `reports/master/MASTER_INTEGRATION_CATALOG.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/**`
- `_ORVION_CANONICAL/21_offline_conversion_engine.md`
- `_ORVION_CANONICAL/30_database_conventions.md`
- `_ORVION_CANONICAL/34_authentication_and_identity_principles.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/evidence/primary-ledger-evidence.json`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `GOVERNANCE.md`
- `reports/master/MASTER_GAP_REGISTER.md` (OWNER-1, A3, MONEY-1, MONEY-2, SYSADMIN-1, AUTH-1, SPP-3, RET-2, AUDIT-4, DELIV-1, PH8-2…PH8-8, CONV-7, CONV-8, BOOK-10, PAY-3, EVT-2, CTRL-1)
- `reports/master/MASTER_INTEGRATION_CATALOG.md` §2, §2a, §3; `reports/architecture-decision-records.md` ADR-0023, ADR-0027, ADR-0028
- `_ORVION_CANONICAL/21_offline_conversion_engine.md`, `28_permissions_matrix.md`, `30_database_conventions.md` § Money Standard
- `changes/SPEC-233-payment-conversion-finds-its-lead.md` (the recovery and CTRL-3's reproduction)
- `developers.google.com/data-manager/api`: events.ingest, requestStatus.retrieve, offline send-events, diagnostics, limits, best practices, Encoding, Consent, FieldWarning, release notes

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
| Test 138 asserts `system_administrator` holds no permission | full pgTAP; `role_permissions`; `app.has_permission` | VERIFY | Test SHA-256 `8e16df6e49ec66a6ccb671ec2c5053b95f8bbcbfba9f521788bbe0baf466cb4e`, `plan(3)`, 3/3 on the local stack. Granting the role one permission inside the transaction fails exactly assertions 2 and 3. It writes nothing that outlives its transaction. |
| ADR-0029, item 11 and MONEY-3 | `architecture-decision-records.md`; `MASTER_ARCHITECTURE_DECISIONS.md`; the register; Checks 1, 21 | WRITE | ADR-0029 records SPEC-118's implemented standard and does not ratify `payments.account_amount numeric(18,4)`; MONEY-3 records it with its consequence and trigger. No financial semantics change. |
| Canon 28 `system_administrator` | canon readers; Check 16 | WRITE | One paragraph under the role heading; the permissions table is unchanged. |
| Registry status, §2a corrections 9–11, the re-verification note and §2b | `MASTER_INTEGRATION_CATALOG.md`; the Activation Closure contracts | WRITE | Documentation only. §2b becomes the Activation Closure's condition list, not a deferral list; no RPC or table changes. |
| Register rows and blocks | `MASTER_GAP_REGISTER.md`; Checks 2, 11, 14, 16, 21, 25 | WRITE | A3, PH8-6 and PH8-4 become settled; PH8-9, MONEY-3 and CTRL-3 are added with Owner Decision `—`; CONV-8, BOOK-10 and PAY-3 record that their trigger fired; the other listed OWNER-1 items gain verified-state and trigger text without changing their settled lead. |
| Manifest `Next capability`, suite figure, Last Completed, Active pointer; `ai-map.json` | Boot's `NEXT_CAPABILITY`; Checks 5, 7, 15, 25 | WRITE | Next capability becomes Phase-8 Activation Closure, with Slice 31 paused; the suite becomes 138 files / 2466 assertions; the open-decision line is unchanged. |
| Suite, smoke and the declared HTTP suite | full pgTAP; `scripts/verify_database.sql`; `verify_role_journeys.ps1` | VERIFY | No schema change; the declared suite exercises role resolution, which this contract does not alter. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Manifest suite figure equals the files and plan sum | BEFORE_COMPLETION | Step 1 | Step 3 | Step 4 |
| `ai-map.json` matches its generator | BEFORE_COMPLETION | Step 2 | Step 3 | Step 4 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: three existing homes carry everything except one assertion.

- The register's settled and decider signals (Checks 14 and 25) keep owner decisions on the manifest's boot line.
- The integration catalog's `§2a` carries the Data Manager contract.
- ADRs live in `architecture-decision-records.md`.

The only new control is one pgTAP file asserting a decided invariant that nothing asserted. Alternatives rejected:

- **A new tracking document for the Activation Closure:** the manifest's next capability and the catalog's §2b already express it.
- **Implementing any Activation Closure item here:** each has its own contract, and this one stays governance-only.
- **Ratifying or widening `numeric(18,4)` now:** neither is earned.
- **Repairing CTRL-3:** it has one fail-closed occurrence, and its trigger is recorded.

Added Property: `system_administrator` holding a permission fails the suite. Boot names the Phase-8 Activation Closure as the next capability until it closes.

Causal Negative: On the local stack at `3759ef7`, granting `system_administrator` one permission raised no failure anywhere in the suite. The manifest named Slice 31 while five activation conditions were open.

Positive Test Design: The role exists and is active. An `employee` in the same tenant resolves to at least one permission.

Negative Test Design: `system_administrator` holds zero `role_permissions` rows, and a member holding only that role resolves to no permission in the catalog through `app.has_permission`.

Non-Empty Population Obligation: One tenant, one member holding only `system_administrator`, one member holding `employee`, and the whole permission catalog.

Mutation Obligation: Grant `system_administrator` one permission inside the transaction and prove assertions 2 and 3 fail, then prove they pass without it. Record this in the Execution Log at Step 4.

Post-Implementation Proof Obligation: The focused test, clean reset, pgTAP Pass A, the declared HTTP suite, pgTAP Pass B, smoke, generated artifacts, repository consistency and `git diff --check`, all through canonical `-Finish`.

## Implementation Steps

1. **Check** that `supabase/tests/138_reserved_role_holds_no_permission_test.sql` is absent. If absent, create it LF with SHA-256 `8e16df6e49ec66a6ccb671ec2c5053b95f8bbcbfba9f521788bbe0baf466cb4e` and `select plan(3);`:
   - (1) the role is active;
   - (2) it holds zero `role_permissions`;
   - (3) a member holding only it resolves to no permission, while an `employee` in the same tenant resolves to some.

   If the target exists with different bytes, stop.
2. **Check** whether `reports/architecture-decision-records.md` contains `## ADR-0029`. If absent, apply the documentation edits exactly as prototyped:
   - **ADR-0029:** inserted before `## Programme lesson numbering`. It records SPEC-118, the measured state and the MONEY-3 divergence it does not ratify.
   - **`MASTER_ARCHITECTURE_DECISIONS.md`:** a dated freshness line, and item 11 marked decided (ADR-0029, pointer to MONEY-3).
   - **Canon 28:** the reserved-role paragraph under `## system_administrator`.
   - **`MASTER_INTEGRATION_CATALOG.md`:**
     - the Google Ads registry status becomes "NOT OPERATIONAL — Phase-8 Activation Closure in progress (§2b)", with its reasons;
     - corrections **9** (`eventSource`: `PHONE` for `qualified_phone_call`, `OTHER` for the four CRM outcomes), **10** (one destination per conversion action) and **11** (the asynchronous contract with `REQUEST_STATUS_UNKNOWN`/`PROCESSING`/`SUCCESS`/`PARTIAL_SUCCESS`/`FAILED`, the one-event v1 with its quota evidence and revisit trigger, and the ORVION-side state change required);
     - the re-verification note;
     - **§2b Phase-8 Activation Closure** with five items: door parity (CONV-8/BOOK-10/PAY-3); PH8-4 as decided, with its consent boundary; PH8-9; the workflow itself; and the candidates classified during the closure (PH8-2/DELIV-1, PH8-3, PH8-5, PH8-7, PH8-8).
   - **Register:**
     - a dated freshness entry;
     - A3 settled with ADR-0029;
     - PH8-6 `✅ RESOLVED BY DERIVATION`;
     - PH8-4 `✅ DECIDED BY THE OWNER 2026-09-28`, with Owner Decision "engineering (owner SETTLED 2026-09-28)" and its detail block extended by the decision, the consent boundary and the implementation shape;
     - **PH8-9** added after PH8-8 as a current activation blocker;
     - **MONEY-3** added after MONEY-2;
     - **CTRL-3** added after CONV-8;
     - CONV-8, BOOK-10 and PAY-3 annotated that their trigger fired;
     - verified-state and trigger text appended to AUDIT-4, PH8-2, PH8-3, PH8-5, PH8-7, PH8-8, AUTH-1, SYSADMIN-1, SPP-3, RET-2 and DELIV-1, without changing their settled lead.

     No other row changes.

   If any target already carries different content, stop.
3. **Check** that the manifest's `Next capability` names the Phase-8 Activation Closure. If not:
   - Set it, stating that Batch 6 Slice 31 is paused until the closure ends.
   - Set the suite figure from the measured file count and plan sum (138 / 2466; stop if the measurement differs).
   - Set `Last Completed`, keeping the manifest within 7000 characters and leaving the open-decision line unchanged.
   - Regenerate `ai-map.json` LF. `MASTER_API_CONTRACT.md` is regenerated and expected byte-identical.
4. **Check** for a `Local certification` Execution Log entry. If absent:
   - Run the focused test and its one-grant counterfactual.
   - Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`.
   - Review against every Acceptance Criterion. After `Verdict: Confirmed Complete`, set Runtime Checkpoint DONE, transition Complete and clear `Active Change Request`.
   - Prove the range with `-Gate -BaseRef origin/main`, publish the exact candidate, require exact-SHA candidate CI, promote the same SHA, run `-Certify` for `REMOTE_CERTIFY: READY`, and verify synchronized clean refs.

## Acceptance Criteria

- [ ] ADR-0029 exists and records the implemented money-storage standard and its revisit trigger without ratifying `payments.account_amount numeric(18,4)`. MONEY-3 records that with its consequence, its WORTH IT classification and its trigger. Item 11 no longer calls it open.
- [ ] Canon 28 records `system_administrator` as reserved with no seeded permission. Test 138 asserts it, with a counterfactual that fails exactly its decisive assertions.
- [ ] PH8-4 is recorded as the owner decided it on 2026-09-28, with the consent boundary and the counsel question kept separate, and its implementation placed in the Activation Closure.
- [ ] PH8-9 is a current activation blocker, and corrections 9–11 match Google's current documentation, including the `FAILED` spelling and the `requestStatus.retrieve` endpoint.
- [ ] `MASTER_INTEGRATION_CATALOG.md` §2b lists the Activation Closure conditions, and the registry status no longer claims completion. CONV-8, BOOK-10 and PAY-3 record that their trigger fired.
- [ ] PH8-6 is resolved by derivation and CTRL-3 is recorded with its reproduction and trigger. Every other OWNER-1 item touched carries its verified state and trigger, and its settled state is unchanged.
- [ ] Boot names the Phase-8 Activation Closure as the next capability, with Slice 31 paused. The manifest (138 files / 2466 assertions; open decisions MAIL-1, RET-1) and `ai-map.json` agree, and repository consistency is clean.
- [ ] There is no migration and no Primary write, and Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-09-28 — Owner approval

The owner approved the exact Draft SHA `7883f43b18bd2872657d2aaaef2df7dded30d8d7`, Test-138 SHA-256 `8e16df6e49ec66a6ccb671ec2c5053b95f8bbcbfba9f521788bbe0baf466cb4e` and the frozen ten-path Write Scope, with profiles DATABASE and REPOSITORY and no Primary impact, so no Human Gate 2 applies.

Revalidation before approval:
- HEAD was the Draft, a direct descendant of the certified `23629c1`, and the tree was clean.
- `origin/main` and `origin/orvion-preflight` were at `23629c1`.
- Test 138 hashes to the approved value.
- A read-only evaluation of the committed Draft returned `APPROVAL_EVIDENCE: PASS`. Two mutated copies returned FAIL (a gate at Step 2 inside the red window 1..3) and INDETERMINATE (the Mutation Obligation removed).
- The manifest measured 6619 of 7000 characters.

With the approval, the owner ratified PH8-4 again as recorded in this contract. The owner also delegated technical and operational definitions in the Phase-8 Activation Closure to engineering, reserving legal, commercial and external-account decisions. This contract implements none of the closure.

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

- **EARN IT.** Every edit was earned by a measurement, a decision or an incident on 2026-09-28:
  - an ADR that does not exist while a Master calls its decision open;
  - a decided invariant that nothing asserts;
  - a canon cell inviting what the owner forbade;
  - an owner decision that must not disappear;
  - an acknowledgement that would lose a conversion Google later rejects;
  - a registry claiming completion;
  - a next capability pointing past open activation conditions;
  - a precision divergence nobody explained;
  - a false red in the allocation check.
- **WORTH IT.** Documentation and one read-only test, with no migration and no Primary write. Every Activation Closure repair is its own contract.
- **Deliberately not changed:**
  - AUTH-1's tables: retirement is a migration with its own trigger.
  - SPP-3: a contract, not a column.
  - RET-2 and AUDIT-4's later purposes: owed at their triggers.
  - The Gate: CTRL-3 is recorded, not repaired.
  - MAIL-1 and RET-1: owner and counsel.

  The registered worktree `owt/p2` is untouched.
