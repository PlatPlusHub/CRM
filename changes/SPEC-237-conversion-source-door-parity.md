# Change Request — SPEC-237

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Close CONV-8 for its two events: make `lead_qualified` and `booking_created` each produced by one AFTER trigger on every legal door, remove the RPCs' own emission so no act is recorded twice, and prove that a lead qualified or a booking created at the table door reaches the offline-conversion pipeline exactly as the sanctioned RPC path does. This is the first contract of the Phase-8 Activation Closure (`MASTER_INTEGRATION_CATALOG.md` §2b item 1).

## Business Reason

The manifest's next capability is the Phase-8 Activation Closure, and CONV-8's trigger has fired: the conversion system may not be called live while a legal business act produces no conversion.

- **The intended rule.** ADR-0023 and canon 21: ORVION turns verified CRM outcomes into offline conversions. `app.map_outcomes_to_conversions` maps `lead_qualified → qualified_lead` and `booking_created → booking_created`, keyed on `source_event_seq`.
- **CONV-8 (Medium, reproduced, latent).** Each event had one producer, its RPC. `authenticated` holds UPDATE on `leads` and INSERT on `bookings`, and `app.enforce_status_transition` lets the assigned handler move a contacted lead to `qualified` at the table door, so the same act done there was silent. Measured again on the local stack at `6c6e20e`, in rolled-back transactions, with a consented Google Ads click on every lead: the handler's direct qualification and an `employee`'s direct booking produced no event and no conversion, while `app.advance_lead` and `app.create_booking` produced both. `137_...` assertions 15-16 pin exactly that and were written to fail on repair.
- **Exposure.** Primary holds 0 tenants and 0 offline conversions, and no delivery workflow exists, so the defect is latent until the first tenant's pipeline runs.
- **The repair is SPEC-215's shape (`supplier_created`), not a new mechanism.** One AFTER ROW trigger is the event's single producer and the RPC loses its own `app.record_event`:
  - `bookings_emit_created` fires AFTER INSERT on `bookings`. The payload keys are the ones `app.create_booking` wrote (`lead_id`, `customer_id`, `booking_reference`, `quotation_id`), read from the row it wrote them into.
  - `leads_emit_qualified` fires AFTER UPDATE OF `lead_status_code` when a lead enters `qualified`. A signed-in caller cannot create a lead already `qualified` (LEAD-2), so entering `qualified` is the business act. `app.advance_lead` accepts a free-text reason; it now passes that reason to the trigger through a transaction-local setting, which the trigger reads and then clears. The reason is caller-supplied text on either door, so this channel carries no authority.
  - `app.record_event` takes the actor from the session and stamps the time, so neither door can name another actor or backdate the event, and session-less writes are recorded with a null actor.
- **Not in this contract.** `booking_issued` and the issuance rules are BOOK-10, and `payment_recorded` is PAY-3. Each is its own Activation Closure contract, because each carries its own design choice.

## Risks

- **An event recorded twice would be a conversion uploaded twice.** Mitigated by three things:
  - The RPCs no longer emit these two events, and each trigger is the only producer in the schema. A census of every function body found no other writer of either event code, and `app.create_booking` is the only function that inserts bookings.
  - The source-event key `source_event_seq` is unique on `offline_conversions`.
  - Test 139 asserts exactly one event per act on both doors, and an out-of-test mutant that restores the RPC's own emission is killed.
- **A reason leaking from one qualification to another.** Mitigated: the trigger clears the setting after reading it and the setting is transaction-local. Test 139 qualifies at the door after an RPC qualification with a reason, in the same transaction, and asserts a null reason; a mutant that does not clear it is killed.
- **Tests that hand-wrote these events.** `27_...` hand-wrote a `booking_created` fixture event and now double-counts; its fixture stops writing it. `137_...` assertions 2, 11 and 15-16 move to the repaired counts. The prototype's full suite found no other consumer.
- **Primary deployment adds two triggers and replaces two function bodies in production.** It requires separate exact-byte owner authorization (Gate 2). Approving this contract does not authorize it.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-237-conversion-source-door-parity.md`
- `supabase/migrations/20260928160000_a_qualified_lead_and_a_booking_are_recorded_on_every_door.sql`
- `supabase/tests/139_qualified_lead_and_booking_are_recorded_on_every_door_test.sql`
- `supabase/tests/137_conversion_sources_reach_the_pipeline_test.sql`
- `supabase/tests/27_event_visibility_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_INTEGRATION_CATALOG.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607056900_a_scheduled_job_may_not_lose_work_silently.sql`
- `supabase/migrations/20260928140000_a_payment_conversion_finds_its_lead_through_its_invoice.sql`
- `supabase/migrations/20260924130000_supplier_creation_is_recorded.sql`
- `supabase/tests/09_conversion_delivery_lease_test.sql`
- `supabase/tests/13_conversion_identity_snapshot_test.sql`
- `supabase/tests/78_marketing_conversion_integrity_test.sql`
- `supabase/tests/109_lead_authority_and_lifecycle_test.sql`
- `supabase/tests/119_conversion_provenance_is_platform_written_test.sql`
- `supabase/tests/121_supplier_creation_is_recorded_test.sql`
- `_ORVION_CANONICAL/21_offline_conversion_engine.md`
- `_ORVION_CANONICAL/26_state_machines.md`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/architecture-decision-records.md`
- `scripts/verify_database.sql`
- `scripts/verify_lifecycle_branches.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/21_offline_conversion_engine.md`; `_ORVION_CANONICAL/26_state_machines.md` (Lead, Booking); `_ORVION_CANONICAL/27_event_catalog.md` (`lead_qualified`, `booking_created`)
- `supabase/migrations/20260924130000_supplier_creation_is_recorded.sql` and `supabase/tests/121_supplier_creation_is_recorded_test.sql` (the shape reused)
- Current local `app.create_booking`, `app.advance_lead`, `app.record_event`, `app.enforce_status_transition`, `app.map_outcomes_to_conversions`
- `reports/master/MASTER_GAP_REGISTER.md` (CONV-8, BOOK-10, PAY-3, LEAD-2); `reports/master/MASTER_INTEGRATION_CATALOG.md` §2b

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

- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| `lead_qualified` is produced by `leads_emit_qualified` on every door, and no longer by `app.advance_lead` | `app.map_outcomes_to_conversions`; `app.customer_timeline`; `events` readers | VERIFY | The prototype was applied as a real migration on a clean reset in a scratch worktree at `6c6e20e`: migration SHA-256 `83a21861ef7f6b4067fc2e49b9bc75109f20d57c39becff6048505bab9ff95fb`, Test-139 SHA-256 `14d21b48766cee9fc744fd423a8c19b1ad0c6e69a7a69b4013914877d0b963f5`. The RPC path records exactly one event with the same actor, states, reason, severity and null payload as before; the door path records one naming the handler. |
| `booking_created` is produced by `bookings_emit_created` on every door, and no longer by `app.create_booking` | `app.map_outcomes_to_conversions` (reads `payload.lead_id`); `app.customer_timeline`; `27_...` | VERIFY | The RPC path records exactly one event with the caller as actor, `draft` as new state and the same four payload keys, read from the row; the door path records one naming its creator and lead. |
| Every other `app.advance_lead` event and every `app.create_booking` guard | `109_...`, the lead and booking suites; the HTTP lifecycle suites | VERIFY | Unchanged. Test 139 proves `lead_quotation_sent` is still the RPC's own, exactly once, and the full suite passes. |
| Hand-written fixture events | `27_...` (a `booking_created` fixture event); `137_...` (pinned-open assertions and counts) | WRITE | `27_...` stops hand-writing the event its booking now produces (9 assertions unchanged). In `137_...`, assertion 2 moves to `[2, 1, 4, 1]`, assertion 11 to seven conversions, and 15-16 flip from pinned-open to closed. No other test changes. |
| Suite, smoke and every HTTP door | full pgTAP; `scripts/verify_database.sql`; all six HTTP suites | VERIFY | On the prototype stack, in `-Finish`'s order: pgTAP Pass A 139 files / 2485 assertions PASS (the 2466 existing, with `137_...` 2, 11, 15-16 and `27_...`'s fixture moved as stated, plus 19 new); HTTP suites 33 + 40 + 74 + 122 + 120 + 60 = 449 passed, 0 failed; Pass B without reset 139 / 2485 PASS; smoke `ALL CHECKS PASSED`, exit 0. |
| The generated API surface | `MASTER_API_CONTRACT.md`; `check_database_parity_evidence.ps1` Check L3 | VERIFY | No RPC, view or table changes: the two emitters return `trigger` and are not endpoints, and the regenerated contract is byte-identical (79 RPC endpoints, 8 views, 73 tables). It is regenerated in Step 7. |
| Measured state that moves | manifest (`Live state`, suite figure, Last Completed, Active pointer); `primary-ledger-evidence.json`; `ai-map.json`; Checks 5, 7, 15, 19 | WRITE | 235 → 236 migrations, latest `20260928160000`; 138 → 139 files / 2466 → 2485 assertions. Primary values are written only from fresh post-deploy readings. |
| Findings, disposition and the activation list | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; `MASTER_INTEGRATION_CATALOG.md` §2b; Checks 2, 11, 16, 21, 22, 24, 25 | WRITE | CONV-8 becomes fixed for its two events, with `payment_recorded` and `booking_issued` still owned by PAY-3 and BOOK-10. The `offline_conversions` disposition row stays `PARTIAL` / `ADVERSARIAL` and gains Test 139. §2b item 1 records CONV-8 closed. No other row changes. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused tests, pgTAP A/B, the declared HTTP suite, smoke and in-file mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| CONV-8, the `offline_conversions` disposition and §2b accurately describe local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite figure equals the files and plan sum | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: SPEC-215's single-producer event trigger (`suppliers_emit_created` → `app.emit_supplier_created`, SECURITY DEFINER, EXECUTE revoked from PUBLIC, the RPC's own emission removed), with `app.record_event` owning the actor and the time. It is reused unchanged for two tables. The alternatives were rejected:
- closing the table doors (revoking UPDATE on `leads` or INSERT on `bookings`): the state machine deliberately permits the handler's transition and the grants are designed doors used by other flows and suites, so that would change authority, not observability;
- keeping the RPCs' emission and adding a trigger that skips when an RPC is running: two producers joined by a flag is the double-emission risk this shape exists to remove;
- deriving conversions from table state instead of events: it discards `source_event_seq`, the idempotency key the mapper and delivery depend on.

Added Property: Every business act that inserts a booking or moves a lead into `qualified`, on any door, records exactly one source event naming the session's actor, and so yields exactly one conversion when its lead carries an attribution click.

Causal Negative: On the local stack at `6c6e20e`, in rolled-back transactions, with a consented Google Ads click on each lead, the assigned handler's direct UPDATE of a contacted lead to `qualified` and an `employee`'s direct INSERT of a booking each produced no source event and no conversion.

Positive Test Design: As the handler at `aal2`, qualify one lead through `app.advance_lead` with a reason and another at the table door; as the owner, create a booking through `app.create_booking`; as the handler, create one at the table door; as `postgres` with no session, create one on the platform path. Then run the real mapper.

Negative Test Design:
- An edit of a qualified lead records no second event.
- Leaving `qualified` through the RPC records the RPC's own event and no `lead_qualified`.
- The state machine still refuses `assigned → qualified` at the door with its own message and leaves no event.
- The RPC's reason does not leak onto a later door qualification in the same transaction.
- A further mapper run adds nothing.
- Every booking and every lead that entered `qualified` carries exactly one source event.

Non-Empty Population Obligation: One tenant, one branch and department, an owner and an `employee` handler, one customer, seven leads each carrying a consented first-touch Google Ads click and assigned to the handler, six of them contacted, plus one session-less platform booking.

Mutation Obligation: In the file, in a savepoint, drop `leads_emit_qualified` and `bookings_emit_created`, repeat a door qualification and a door booking, and prove both are silent and the mapper produces nothing. Roll back and prove the identical writes are recorded again. Out of file, record the md5 of the three function definitions, install each mutant, prove the md5 differs, run Test 139, restore and prove the md5 matches:
- M-A: `app.create_booking` keeps its own emission. Expected to fail assertion 9.
- M-B: `app.emit_lead_qualified` does not clear the reason. Expected to fail assertion 4.
- M-C: `app.advance_lead` does not pass its reason. Expected to fail assertion 2.

A mutant whose installation is not proven is a harness error, never a killed mutant.

Post-Implementation Proof Obligation: All of the following, on the final bytes and through canonical `-Finish`:
- the focused tests, a clean reset, pgTAP Pass A, the declared HTTP suite, pgTAP Pass B and smoke;
- the in-file and out-of-file mutations and the unrepaired counterfactual;
- the generated artifacts;
- fresh Primary evidence, parity evidence and the Primary ledger check;
- repository consistency and `git diff --check`.

## Implementation Steps

1. **Check** that `supabase/migrations/20260928160000_a_qualified_lead_and_a_booking_are_recorded_on_every_door.sql` is absent. If absent, create it LF with SHA-256 `83a21861ef7f6b4067fc2e49b9bc75109f20d57c39becff6048505bab9ff95fb`. It holds:
   - `app.emit_booking_created()` and `app.emit_lead_qualified()`, each `language plpgsql security definer set search_path to ''`, with EXECUTE revoked from PUBLIC;
   - trigger `bookings_emit_created`, AFTER INSERT ON `public.bookings` FOR EACH ROW;
   - trigger `leads_emit_qualified`, AFTER UPDATE OF `lead_status_code` ON `public.leads` FOR EACH ROW WHEN the new status is `qualified` and the old one is distinct from it;
   - `app.create_booking`, byte-identical to the live body except that its `app.record_event` call is replaced by a one-line CONV-8 comment;
   - `app.advance_lead`, byte-identical to the live body except two changes. Before its UPDATE, when the event is `lead_qualified`, it sets `app.transition_reason` transaction-locally to `coalesce(p_reason, '')`. Its `app.record_event` call is wrapped in `if v_event <> 'lead_qualified'`.

   It changes no grant, policy, guard, state transition or other function. If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/139_qualified_lead_and_booking_are_recorded_on_every_door_test.sql` is absent. If absent, create it LF with SHA-256 `14d21b48766cee9fc744fd423a8c19b1ad0c6e69a7a69b4013914877d0b963f5`. It is one transaction-rolled-back pgTAP file with `select plan(19);`. Its `-- ATTACK-CLASSES:` line reads `DOOR BUSINESS STATE OBSERVABILITY PRIVILEGE REPLAY TENANT=N/A AUTH=N/A CONCURRENCY=N/A INPUT=N/A`, and its header states each `N/A` reason. It implements:
   - the Positive and Negative Test Design;
   - the emitters' privilege and trigger shape;
   - the platform path;
   - the in-file Mutation Obligation;
   - completeness.

   Then edit two existing tests, each LF, stopping on any mismatch:
   - `supabase/tests/27_event_visibility_test.sql`: remove its hand-written `booking_created` fixture insert and state why, SHA-256 `af09b98746f866175336e656f7306505dba8542046cc99b9dbecf875df7f2b6e`, `plan(9)` unchanged.
   - `supabase/tests/137_conversion_sources_reach_the_pipeline_test.sql`: change assertion 2 to `[2, 1, 4, 1]`, assertion 11 to `[0, 7]`, and assertions 15-16 to assert that the door qualification and the door booking each produce their conversion; update the header's CONV-8 paragraph. SHA-256 `040132386fc9886ce7712f57fa38beebef8a7555f6644e8e99978a04fb4c0f0c`, `plan(16)` unchanged.

   If a target carries different content, stop.
3. **Check** whether the CONV-8 row in `reports/master/MASTER_GAP_REGISTER.md` still reads `**OPEN — reproduced with SPEC-233`. If it does:
   - Add a dated freshness entry and demote the previous one to `Previously:`.
   - Keep every CONV-8 cell except Status. Prefix its Status with a bold statement that SPEC-237 (`20260928160000`) fixed it locally for `lead_qualified` and `booking_created`, pending Primary deployment, and that `payment_recorded` and `booking_issued` remain PAY-3's and BOOK-10's. State that `137_...` 15-16 now assert the repaired behaviour and that `139_...` proves the parity.
   - Change no other row.

   In `reports/master/MASTER_SURFACE_DISPOSITION.md`:
   - The `offline_conversions` row stays `PARTIAL` / `ADVERSARIAL`, its CR becomes `SPEC-237-conversion-source-door-parity`, and its Next cell gains Test 139, with PAY-3 and BOOK-10 as the remaining creation-event axes.
   - Add a dated freshness entry and demote the previous one.
   - Coverage and every other row are unchanged.

   In `reports/master/MASTER_INTEGRATION_CATALOG.md`, append to §2b item 1 that CONV-8 is closed by SPEC-237, with BOOK-10 and PAY-3 remaining.

   If a target already carries different content, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 hashes:
   - a clean local reset and the focused tests;
   - pgTAP Pass A, the declared HTTP suite, then pgTAP Pass B without reset;
   - `scripts/verify_database.sql` and the plan sum;
   - the in-file and out-of-file mutation evidence and the unrepaired counterfactual;
   - the API-contract and map generators;
   - the scope check, `git diff --check` and repository consistency.

   Treat only undeployed Primary, manifest and parity drift as expected at this boundary. Read a fresh Primary baseline, read-only:
   - the full ordered ledger and the absence of the target migration;
   - the function and structural surfaces;
   - the tenant, lead, booking, event and offline-conversion counts;
   - the current definition md5 of `app.create_booking` and `app.advance_lead`, and the absence of both emitters and both triggers.

   Record the predicted structural delta.
5. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 4 and present:
   - the current HEAD and the exact hashes;
   - the fresh Primary baseline and the predicted delta;
   - the exact Primary write requested.

   Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20260928160000_a_qualified_lead_and_a_booking_are_recorded_on_every_door`. If it is absent and deployment is separately authorized:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts and both pre-repair md5 values.
   - On an exact match, apply only the authorized migration through the Primary connector. If the connector assigns a temporary version, normalize only its newly inserted ledger row.
   - Read fresh: the ledger, the function surface and all ten structural surfaces, both emitters' security mode, `search_path` and EXECUTE ACL, and both triggers.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`:
     - set the `Live state` migration count, latest version, ledger and surface hashes and counts from the same readings;
     - confirm that `supabase/tests` holds 139 files whose literal `plan(N)` values sum to 2485, then set the suite figure to `Suite **139 files / 2485 assertions**`; if either differs, stop;
     - set `Last Completed` to SPEC-237 / CONV-8, keeping the manifest within 7000 characters.
   - Mark CONV-8 `DEPLOYED` in the register and change its Cert to `✅`.
   - Regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` (stored LF) with the canonical generators.
   - Run `check_primary_ledger.ps1`, `check_database_parity_evidence.ps1`, repository consistency and `git diff --check`.

   If Primary is unproven, stop.
8. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, do all of the following:
     - set Runtime Checkpoint DONE and transition to Complete;
     - keep `Next capability` as the Phase-8 Activation Closure with Slice 31 paused;
     - clear `Active Change Request`;
     - regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate and require exact-SHA candidate CI.
   - Promote the same accepted SHA and run `-Certify` for `REMOTE_CERTIFY: READY`.
   - Verify synchronized clean refs and remove permitted scratch files.

## Acceptance Criteria

- [x] A lead qualified through `app.advance_lead` and a lead qualified by the assigned handler at the table door each record exactly one `lead_qualified`, naming the session's actor. The RPC path carries its caller's reason, the door path carries none, and neither yields a second event on a later edit.
- [x] A booking created through `app.create_booking`, at the table door by an `employee`, and on the session-less platform path each record exactly one `booking_created`. Each names the session's actor (null for the platform) and carries the RPC's four payload keys read from the row.
- [x] Both door acts reach the real mapper as `qualified_lead` and `booking_created`, each keyed to its own event, and a further run adds nothing. `137_...` 15-16 now assert those conversions.
- [x] Every other `app.advance_lead` event is unchanged, and the state machine still refuses what it refused.
- [x] Both emitters are SECURITY DEFINER, executable by neither PUBLIC nor `authenticated`, and each fires AFTER ROW on exactly one event.
- [x] With both triggers dropped in a savepoint, both door acts are silent and produce nothing, and the rolled-back state records them again. Out-of-file mutants M-A, M-B and M-C are each killed, with their installation and restoration md5-proven. On the unrepaired stack, the decisive assertions of Test 139 fail.
- [x] CONV-8 is registered fixed and deployed for its two events, with PAY-3 and BOOK-10 still open. The `offline_conversions` row stays `PARTIAL`, §2b item 1 records CONV-8 closed, and every other row and the Coverage totals are unchanged.
- [x] The migration and tests match their SHA-256 values. Primary, the recorded evidence, the manifest (236 migrations; 139 files / 2485 assertions), the API contract and `ai-map.json` agree.
- [x] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and no business-data write, and Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [x] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-09-28 — Owner approval

The owner approved the exact Draft SHA `53ee39e2c779cf787de37a770f4db821ff293f30` (CR SHA-256 `84e7417d4e708c15b729897e9868c2c25ff2d4e4aa6ba61f5281d04c9a6ef7cc`) and the frozen twelve-path Write Scope. The approval covers Approve, In Progress, Steps 1-4 and full local readiness only. Primary remains read-only and requires Human Gate 2.

The approval is bound to four SHA-256 values:
- migration `20260928160000`: `83a21861ef7f6b4067fc2e49b9bc75109f20d57c39becff6048505bab9ff95fb`;
- Test 139: `14d21b48766cee9fc744fd423a8c19b1ad0c6e69a7a69b4013914877d0b963f5`;
- Test 137: `040132386fc9886ce7712f57fa38beebef8a7555f6644e8e99978a04fb4c0f0c`;
- Test 27: `af09b98746f866175336e656f7306505dba8542046cc99b9dbecf875df7f2b6e`.

The owner named seven invariants to preserve:
1. `lead_qualified` has exactly one producer on every legal door.
2. It fires only on the genuine transition into `qualified`, never on an unrelated update to an already-qualified lead.
3. `booking_created` has exactly one producer per booking row.
4. `app.advance_lead` and `app.create_booking` no longer duplicate those events.
5. An RPC qualification's reason reaches only its own `lead_qualified`.
6. A direct qualification with no reason inherits no stale transaction or session context.
7. This contract authorizes no change to authorization, lifecycle semantics, mapper meaning, conversion action, attribution, consent or the API contract.

The three mutation classes (duplicate event, reason leakage, reason loss) must stay load-bearing. PAY-3, BOOK-10, PH8-4 and PH8-9 are not absorbed.

Revalidation before approval:
- HEAD was the Draft, a direct descendant of the certified `6c6e20e`, and the tree was clean.
- `origin/main` was at `6c6e20e`.
- The Draft file hashes to the approved value.
- A read-only evaluation of the committed Draft returned `APPROVAL_EVIDENCE: PASS` (profiles DATABASE and REPOSITORY, three permanent-control paths in scope).
- Two mutated copies returned FAIL (a gate at Step 4 inside the red window 1..7) and INDETERMINATE (the Mutation Obligation removed).

### 2026-09-28 — Execution started

The approved twelve-path contract entered In Progress at `1dfbf876601fe0ff2d9b34fde015861357159426`. Resume Step 1. Primary stays read-only until Human Gate 2.

### 2026-09-28 — Steps 1-3 applied (uncommitted until after deployment)

- **Step 1: Applied.** The migration `20260928160000` was created LF, SHA-256 `83a21861ef7f6b4067fc2e49b9bc75109f20d57c39becff6048505bab9ff95fb`.
- **Step 2: Applied.**
  - Test 139 was created LF, SHA-256 `14d21b48766cee9fc744fd423a8c19b1ad0c6e69a7a69b4013914877d0b963f5`, `plan(19)`.
  - Test 137 was edited, SHA-256 `040132386fc9886ce7712f57fa38beebef8a7555f6644e8e99978a04fb4c0f0c`, `plan(16)`.
  - Test 27 was edited, SHA-256 `af09b98746f866175336e656f7306505dba8542046cc99b9dbecf875df7f2b6e`, `plan(9)`.
- **Step 3: Applied.**
  - The register gained a freshness entry and CONV-8's Status was prefixed. The disposition gained a freshness entry, and its `offline_conversions` row's CR and Next cell were updated. §2b item 1 was annotated.
  - No other row changed.
  - These three files are byte-identical to the prototype's.

Per the DATABASE sequencing, these seven paths stay uncommitted until Primary is deployed and the manifest remeasured.

### 2026-09-28 — Pre-deploy readiness gate

Run on HEAD `9252855a152fd8643e0ee8876ab453774b44b26d`, with the four files at their approved hashes. Results:
- **Reset:** clean local reset to 236 migrations, latest `20260928160000`.
- **Focused tests:** Test 139 19/19, Test 137 16/16, Test 27 9/9.
- **Out-of-file mutants:** base md5 of the three definitions `7edc1f779aff547e690bf591b300a896`. Each mutant's installation was proven by a changed md5 and each restoration by the base md5.
  - M-A (duplicate event) is killed at assertion 9.
  - M-B (reason leakage) is killed at 4, 5 and 17.
  - M-C (reason loss) is killed at 2 and 6.
- **In-file mutation:** with both triggers dropped in a savepoint, the door acts are silent and the mapper adds 0. Restored, they are recorded again and the mapper adds 2 (assertions 16-17, inside the suite).
- **Unrepaired counterfactual,** measured in the prototype on the pre-repair 235-migration stack with the identical Test-139 bytes: assertions 4, 5, 12 and 13 fail, then the file aborts because the emitters do not exist.
- **pgTAP Pass A:** 139 files / 2485 assertions PASS.
- **HTTP suites:** 33 + 40 + 74 + 122 + 120 + 60 = 449 passed, 0 failed. The declared `verify_lifecycle_branches.ps1` passed 122/122.
- **pgTAP Pass B,** without reset: 139 / 2485 PASS.
- **Smoke:** `ALL CHECKS PASSED`, exit 0.
- **Plan sum:** 139 files, 2485 assertions.
- **Local emitters:**
  - `app.emit_booking_created()` and `app.emit_lead_qualified()` are both SECURITY DEFINER with `search_path=""` and ACL `{postgres=X/postgres}`.
  - `bookings_emit_created` is tgtype 5 (ROW, INSERT) and `leads_emit_qualified` tgtype 17 (ROW, UPDATE).
  - Definition md5: `app.create_booking` `956efc534e218c39fad3c8c019d480f6`, `app.advance_lead` `161ec7977308effd22b84a34551fe2c0`.
- **Generators:** `MASTER_API_CONTRACT.md` is byte-identical (79 RPC endpoints, 8 views, 73 tables). `ai-map.json` differed only in `generated_at` and was restored.
- **Scope, diff check and consistency:**
  - The seven changed paths are all in Write Scope, and `git diff --check` exited 0.
  - Repository consistency reports exactly the six expected pre-deploy issues: three migration-state drifts, two suite-figure drifts and the undeployed RECOVER-1 migration.

**Fresh Primary baseline,** read-only from `https://vrvtsxexkiiiivlkdxzp.supabase.co`:
- **Ledger:** 235 migrations, fingerprint `782fdc10215971057bf30620050de05e`, latest `20260928140000`, target absent.
- **Function surface:** `666b073e9f2bea6f0cfbf94a650a5d15`, 310 functions.
- **Structural surface:** `_combined` `1fbbfffe75ccba93d66057727f2b9d43`, 3062 objects, with triggers `4d7c099d115fd9c69f30baad533e8069`/299. This matches the recorded evidence.
- **Pre-repair definition md5:** `app.create_booking` `1c9fd20fd16d2fd006c50f4f9f1c3d83`, `app.advance_lead` `7ea1f8216112d187180766e6328b74f5`.
- **Absent:** both emitters and both triggers. `leads` carries 11 triggers and `bookings` 8.
- **Business rows:** 0 tenants, 0 leads, 0 bookings, 0 events, 0 offline conversions.
- **ACL:** Primary has no default function ACL for schema `app`, and SPEC-215's emitter there holds `{postgres=X/postgres}`.

**Predicted delta,** equal to the local post-migration surface:
- **Ledger:** 236 migrations, latest `20260928160000`, fingerprint `c97a2a7ad959f19a710830583b36bd89`.
- **Functions:** `87c960b34aa9347eb4d4a235fef07639`/312.
- **Triggers:** `7cd58b04207eb5d9f01a8d2eef6eb9c1`/301.
- **The other eight structural surfaces:** unchanged.
- **Combined:** `a2f5903d89922eb0442271c312c8c238`/3066.
- **Business rows:** none written.

Stopped at Step 5: Human Gate 2.

### 2026-09-28 — Human Gate 2: owner authorization

The owner authorized, exact-byte and bound to the project and to preconditions, only the migration `supabase/migrations/20260928160000_a_qualified_lead_and_a_booking_are_recorded_on_every_door.sql` with SHA-256 `83a21861ef7f6b4067fc2e49b9bc75109f20d57c39becff6048505bab9ff95fb`, for Primary `vrvtsxexkiiiivlkdxzp`. The associated frozen tests are:
- Test 139: `14d21b48766cee9fc744fd423a8c19b1ad0c6e69a7a69b4013914877d0b963f5`;
- Test 137: `040132386fc9886ce7712f57fa38beebef8a7555f6644e8e99978a04fb4c0f0c`;
- Test 27: `af09b98746f866175336e656f7306505dba8542046cc99b9dbecf875df7f2b6e`.

The authorization covered no business-data write, no reconciliation, and no unrelated policy, grant, function, trigger or migration write. It permitted normalizing only the connector's one newly created ledger row.

The authorization text arrived truncated inside the list of rename conditions. The rename was therefore performed only under the conditions presented at Gate 2:
- exactly one new row;
- its stored statement md5 equal to the file's md5;
- no existing `20260928160000`.

### 2026-09-28 — Step 6: Primary deployment

**Prewrite recheck, all exact:**
- SPEC-237 In Progress. HEAD `07f8fb70630c7b4bfb59fd00717ad1b037421be0` on the approved chain `6c6e20e → 53ee39e → 1dfbf87 → 9252855 → 07f8fb7`.
- The four SHA-256 values matched, and only the seven in-scope paths were dirty. The migration has no CR bytes, and its md5 is `b115fc010f9cec3d9a88eff31ef1da86`.
- The project URL was `https://vrvtsxexkiiiivlkdxzp.supabase.co`.
- The ledger held 235 migrations, fingerprint `782fdc10215971057bf30620050de05e`, latest `20260928140000`, target absent.
- There were 310 functions and 299 triggers, and no emitters.
- `app.advance_lead` md5 was `7ea1f8216112d187180766e6328b74f5` and `app.create_booking` md5 `1c9fd20fd16d2fd006c50f4f9f1c3d83`.
- `leads` had 11 non-internal triggers and `bookings` 8.
- Tenants, leads, bookings, events and offline conversions were all 0.

**Write:**
- The exact file bytes were applied through the Primary connector's `apply_migration` as `a_qualified_lead_and_a_booking_are_recorded_on_every_door`.
- The connector assigned the temporary version `20260928211046`. Its single stored statement has md5 `b115fc010f9cec3d9a88eff31ef1da86` and 13087 bytes, equal to the file.
- One guarded UPDATE renamed only that row to `20260928160000`. The guard required the name and statement md5 to match, exactly one row after `20260928140000`, and no existing target. One row was updated.

**Fresh postwrite reads:**
- **Ledger:** 236 migrations, fingerprint `c97a2a7ad959f19a710830583b36bd89`, latest `20260928160000`, one target row.
- **Function surface:** `87c960b34aa9347eb4d4a235fef07639`/312.
- **Structural surface:** functions `87c960b3…`/312 and triggers `7cd58b04207eb5d9f01a8d2eef6eb9c1`/301; the other eight surfaces are unchanged; combined `a2f5903d89922eb0442271c312c8c238`/3066. Every value equals the recorded prediction.
- **Definitions:** `app.create_booking` md5 `956efc534e218c39fad3c8c019d480f6` and `app.advance_lead` md5 `161ec7977308effd22b84a34551fe2c0`, both equal to local.
- **Emitters:** both SECURITY DEFINER, `search_path=""`, ACL `{postgres=X/postgres}`.
- **Triggers:** `bookings_emit_created` tgtype 5 and `leads_emit_qualified` tgtype 17, both enabled. `leads` now has 12 non-internal triggers and `bookings` 9.
- **Business rows:** 0.

No business-data write was made, and Secondary `brplkqmbzffpxqgkkdzo` was not contacted.

### 2026-09-28 — Step 7: evidence and measured state

- `primary-ledger-evidence.json` was rewritten from the fresh readings only: 236 migrations, `c97a2a7a…`, functions `87c960b3…`/312, structural `a2f5903d…`/3066, commit `07f8fb7`.
- The manifest's `Live state` now shows 236 migrations, latest `20260928160000`, and the same hashes and counts. The suite figure is `Suite **139 files / 2485 assertions**`, confirmed: 139 files, plan sum 2485. `Last Completed` names SPEC-237 / CONV-8, and the manifest measures 6886 of 7000 characters.
- CONV-8 is marked fixed and deployed for its two events, with Cert `✅`.
- `MASTER_API_CONTRACT.md` regenerated byte-identical, and `ai-map.json` was regenerated and stored LF.
- **Checks:**
  - `check_primary_ledger.ps1`: `RECOVER-1 LEDGER EVIDENCE: CLEAN`.
  - `check_database_parity_evidence.ps1`: `PRIMARY PARITY EVIDENCE: CLEAN`.
  - Repository consistency: `CLEAN`.
  - `git diff --check`: exit 0.

### 2026-09-28 — Steps 1-7 complete

Every Implementation Step through Step 7 is applied and evidenced above, so the Runtime Checkpoint is DONE and the contract enters VERIFY for Step 8's canonical `-Finish`. The first `-Finish` returned `FINISH_NOT_READY:EXECUTE` because the checkpoint still read Step 8; nothing was verified or changed by that run.

### 2026-09-28 — Post-deploy local certification

Canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` ran on the clean committed execution HEAD `34371e856bbb555dc9d7bd5e53bf9e59c3cb0cdd` in VERIFY mode, with no telemetry opt-outs. It derived profiles DATABASE and REPOSITORY, passed every mandatory verification, and returned `LOCAL_CERTIFY: READY`:
- reset;
- pgTAP Pass A;
- the declared `verify_lifecycle_branches.ps1`;
- pgTAP Pass B;
- smoke;
- parity evidence;
- the Primary ledger;
- repository consistency;
- `git diff --check`.

### 2026-09-28 — Independent Review of execution commit

Reviewed the committed execution HEAD `34371e856bbb555dc9d7bd5e53bf9e59c3cb0cdd` against the approved Draft `53ee39e` and the frozen twelve-path Write Scope.
- The working tree was clean and the pre-commit Gate reported `ORVION: READY`.
- The range `6c6e20e..HEAD` changes eleven paths, all inside the frozen twelve. The twelfth, `MASTER_API_CONTRACT.md`, regenerated byte-identical.
- The committed migration and Tests 139, 137 and 27 hash to their authorized SHA-256 values.

Acceptance, re-checked against the committed bytes and the recorded evidence:
1. **Lead.** Test 139 assertions 2-5 prove one `lead_qualified` per qualification on each door, naming the session's actor. The RPC path carries its reason and the door path none; a later edit records nothing. Owner invariants 1, 2, 5 and 6 hold.
2. **Booking.** Assertions 9-12 and 15 prove one `booking_created` per booking on the RPC, table and platform doors, with the four payload keys read from the row. Invariants 3 and 4 hold.
3. **Pipeline.** Assertion 13 proves both door acts reach the real mapper, each keyed to its own event, and 18 that a further run adds nothing. `137_...` 15-16 assert the two conversions.
4. **Unchanged behaviour.** Assertion 6 shows every other `app.advance_lead` event unchanged, and 7-8 show the state machine refusing as before. Invariant 7 holds: no grant, policy, guard, mapper, conversion action, attribution, consent or API change. The only structural delta is two functions and two triggers, measured on Primary.
5. **Emitters.** Assertion 14 proves both emitters are SECURITY DEFINER, executable by neither PUBLIC nor `authenticated`, and each fires AFTER ROW on exactly one event. Primary shows ACL `{postgres=X/postgres}`.
6. **Mutation.** The in-file trigger-drop mutation (16-17) holds. Mutants M-A (duplicate), M-B (leakage) and M-C (loss) were each killed, with md5-proven install and restore. On the unrepaired stack, assertions 4, 5, 12 and 13 fail.
7. **Records.** CONV-8 is `✅` fixed and deployed for its two events, with PAY-3 and BOOK-10 open. The `offline_conversions` row stays `PARTIAL`, §2b item 1 records CONV-8 closed, and no other row or Coverage total moved.
8. **Agreement.** Primary, the recorded evidence, the manifest (236 migrations; 139 files / 2485 assertions), the API contract and `ai-map.json` agree, and parity, ledger and consistency are CLEAN.
9. **Primary.** Primary received only the authorized migration and the one guarded ledger rename, with no business-data write. Secondary was never contacted.
10. **Scope.** No file outside Write Scope was created, modified or deleted.

Verdict: Confirmed Complete

Recommendation to human: Set Status to Complete

## Verification Notes

None yet.

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

- **EARN IT.** CONV-8 was reproduced twice and its trigger fired. A conversion system that sees only one of two legal doors undercounts what it claims to measure.
- **WORTH IT.** Two triggers and two small function edits in an existing, proven shape. No grant, policy, guard or mapper changes.
- **Deliberately not changed:**
  - BOOK-10 and PAY-3: each is its own contract.
  - The table doors themselves: they stay open and are now recorded.
  - Canon 27: it describes events, not their producers.
  - The registered worktree `owt/p2` is untouched.
