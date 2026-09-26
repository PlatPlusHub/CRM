# Change Request — SPEC-224

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make the passenger-manifest freeze impossible to escape by moving: a booking item may not leave a booking whose manifest has frozen, and a manifest entry may leave a frozen item only as an attributed post-issue correction by any CORRECT_PASSENGER_MANIFEST holder, with every rule reading one definition of frozen.

## Business Reason

Batch 6 Slice 23 selected `bookings` live at Exposure 10, coverage 234; `branches` was runner-up at 10/578. `bookings.booking_status_code` is what freezes every passenger manifest (PAX-5, and PAX-7's ticketed-identity snapshot shipped in SPEC-223). The cross-table pass reproduced two escapes in rolled-back local transactions, each by an `employee` at `aal2` holding CREATE_BOOKING_ITEM and not CORRECT_PASSENGER_MANIFEST, who was first refused the traveller swap on the issued manifest (`permission denied: CORRECT_PASSENGER_MANIFEST`). (1) The employee moved the issued booking's item to a draft booking (UPDATE 1), swapped the traveller there (UPDATE 1) and moved the item back (UPDATE 1): the issued booking's manifest then named `Mona Second` with no correction reason or stamp. (2) The employee moved one frozen manifest entry onto a draft item, swapped the traveller and moved it back, with the same result. Cause: `app.enforce_booking_item_lifecycle` judges only the booking an item moves TO, and `app.enforce_booking_item_passenger_lifecycle` judges only the item a row moves TO, so neither rule ever asks what is being left. Exposure today is nil: Primary holds 0 bookings, 0 booking items and 0 manifest links.

## Risks

- Both enforcers and the shared `app.guard_write_capability` are restated; each must differ from its installed definition only by the measured additions.
- A legitimate re-parenting between unfrozen bookings or items, and moving an item or row INTO a frozen booking, must keep working.
- A finance manager (CORRECT_PASSENGER_MANIFEST without CREATE_BOOKING_ITEM) must reach the lifecycle rule for a frozen departure without gaining a general relocation door between unfrozen items.
- Primary deployment adds one function and changes three; it requires separate exact-byte owner authorization after local proof.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-224-manifest-freeze-cannot-be-left.md`
- `supabase/migrations/20260926140000_manifest_freeze_cannot_be_left.sql`
- `supabase/tests/129_manifest_freeze_cannot_be_left_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/20260909132000_the_manifest_freezes_when_the_ticket_is_issued.sql`
- `supabase/migrations/20260926130000_frozen_traveller_identity_snapshot.sql`
- `supabase/migrations/202607059400_the_parents_state_is_a_rule_on_every_door.sql`
- `supabase/tests/104_booking_item_passenger_manifest_surface_test.sql`
- `supabase/tests/105_booking_item_service_door_test.sql`
- `supabase/tests/114_passenger_manifest_freeze_and_events_test.sql`
- `supabase/tests/128_frozen_traveller_identity_snapshot_test.sql`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `_ORVION_CANONICAL/31_schema_draft.md`
- `scripts/verify_database.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/28_permissions_matrix.md` (the passenger-manifest freeze rule); `_ORVION_CANONICAL/27_event_catalog.md` (`booking_item_passenger_replaced`, `booking_item_passenger_removed`); `_ORVION_CANONICAL/26_state_machines.md` (Booking)
- Current local `app.enforce_booking_item_lifecycle`, `app.enforce_booking_item_passenger_lifecycle`, `app.guard_write_capability`, `app.record_manifest_change_event`, `app.advance_booking`, `app.map_outcomes_to_conversions`; `supabase/tests/114_passenger_manifest_freeze_and_events_test.sql` and `supabase/tests/128_frozen_traveller_identity_snapshot_test.sql`
- `reports/master/MASTER_SURFACE_DISPOSITION.md` (`bookings`); `reports/master/MASTER_GAP_REGISTER.md` (BOOK-1 through BOOK-9, PAX-5 through PAX-8, ENTRY-1)

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
| One definition of frozen, `app.manifest_is_frozen(status, archived)` | `app.enforce_booking_item_passenger_lifecycle`; `app.enforce_booking_item_lifecycle`; `app.guard_write_capability` | VERIFY | The manifest enforcer's inline set (`issued, reissue, refunded, void, completed` or an archived booking) moves into the helper unchanged, and the item enforcer and the guard read the same helper, so there is still one definition. Measured on the prototype: IMMUTABLE SQL, SECURITY INVOKER, empty `search_path`, ACL `{postgres=X/postgres}`; `authenticated` and `anon` have no EXECUTE, and it lives in `app`, not the API schema, so it is no client RPC. All three callers are SECURITY DEFINER. |
| A booking item cannot leave a booking whose manifest has frozen | direct `booking_items` UPDATE; `app.create_booking_item`; booking void/refund/reissue transitions | VERIFY | No function re-parents an item; the direct UPDATE is the only door. Prototype: the employee, a branch manager holding CORRECT_PASSENGER_MANIFEST and the platform path were each refused moving the issued booking's item out (`a booking item cannot leave a booking whose passenger manifest has frozen`); moving a draft item between draft bookings and moving a draft item INTO an issued booking still landed. An item carries no reason column, so there is no attributed form to allow; changing what was issued stays with the booking's own void/refund/reissue transitions. |
| A manifest entry leaving a frozen item is a post-issue removal: CORRECT_PASSENGER_MANIFEST, a fresh reason, a server stamp | direct `booking_item_passengers` UPDATE; `app.record_manifest_change_event` | VERIFY | Canon 27 already requires a correction reason and actor for a removal after issue. Prototype: the employee was refused with or without a manufactured reason (`permission denied: CORRECT_PASSENGER_MANIFEST`); a branch manager and a finance manager were each refused without a fresh reason (`moving a passenger off a frozen manifest requires its own reason`), and with one the move landed, was stamped with that actor and time, and its `booking_item_passenger_replaced` event carried the reason. Moving an unfrozen entry, including into a frozen item, still landed for the employee. |
| The guard offers CORRECT_PASSENGER_MANIFEST for a FROZEN departure with a fresh reason | `app.guard_write_capability` PAX-5/PAX-7 correction condition | VERIFY | Canon 28 grants the correction to `finance_manager`, which does not hold CREATE_BOOKING_ITEM, so without this case the object-class guard would refuse it before the lifecycle rule. The condition gains exactly one case: `booking_item_id` changes AND the OLD item's booking is frozen (the helper) AND a fresh non-empty reason is supplied. It only widens who reaches the lifecycle enforcer, which still owns the authority, reason and stamp. Containment, measured: a finance manager moving an entry between UNFROZEN items was refused with a reason (`manifest correction evidence is not editable on its own`) and without one by the object-class guard (`permission denied: one of CREATE_BOOKING_ITEM is required to write booking_item_passengers`). |
| PAX-5 and PAX-7 rules, and every other table | Tests 104, 114, 128; the six HTTP suites; the rest of the suite; every other `guard_write_capability` table | VERIFY | Corrected prototype on a clean reset: pgTAP 128 files / 2242 PASS; HTTP 33 + 120 + 40 + 74 + 122 + 60 = 449 passed, 0 failed; `scripts/verify_database.sql` ALL CHECKS PASSED; the PAX-5 swap was still refused and a post-freeze profile rename still left the frozen identity unchanged (PAX-7). Only the `booking_item_passengers` UPDATE branch of the guard changes. |
| Booking lifecycle rules on the direct door | `app.advance_booking`; `app.map_outcomes_to_conversions`; the negative-balance override | UNAFFECTED | Separately reproduced as BOOK-10 (Medium, OPEN): a branch manager with a per-user deny on ALLOW_ISSUE_WITH_NEGATIVE_BALANCE was refused issuing a booking whose customer owed 5000 EGP by the RPC and issued it by direct UPDATE; direct issues record no `booking_issued` (the conversion mapper's `ticket_issued` source) and no risk event. Different invariant and mechanism, and its repair carries a design choice (a direct cancellation cannot carry the required reason), so it is registered, not repaired here. |
| Generated and measured state | API contract; Primary evidence; manifest; disposition; gap register; map | WRITE | The API-contract generator produced identical output under the prototype; it stays in scope because the parity check regenerates it. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused test, pgTAP A/B, six HTTP suites, smoke and installed mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Slice-23 findings and 24/77 disposition describe local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest and Primary ledger/function/structure agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| API contract and map match generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `app.enforce_booking_item_lifecycle` already owns which booking an item may attach to, `app.enforce_booking_item_passenger_lifecycle` already owns the freeze and the post-issue correction rule (CORRECT_PASSENGER_MANIFEST, fresh reason, server stamp), and `app.guard_write_capability` already offers that capability for an attributed correction. Reuse all three: each enforcer gains the missing question about what is being LEFT, the guard offers the same capability for a frozen departure, and the freeze set moves into one helper all three read. No new permission, column, event type or trigger.

Added Property: once a booking's manifest has frozen, nothing leaves it except a manifest entry moved by an attributed correction, which every CORRECT_PASSENGER_MANIFEST holder can make; an item never leaves it.

Causal Negative: An employee without CORRECT_PASSENGER_MANIFEST, refused the swap on an issued manifest, moved the issued booking's item to a draft booking, swapped the traveller and moved it back, and separately moved a frozen manifest entry to a draft item, swapped and moved it back; in both cases the issued booking named a different traveller with no reason or stamp. Every probe rolled back.

Positive Test Design: A draft item moves between draft bookings and into an issued booking; an unfrozen entry moves between unfrozen items and into a frozen item; a branch manager and a finance manager each move a frozen entry off with a fresh reason, stamped with that actor, and the replaced event carries the reason; PAX-5 and PAX-7 behaviour is unchanged.

Negative Test Design: The employee, a branch manager and the platform path are refused moving an item off an issued booking, pinned to its message; the employee is refused moving a frozen entry off with or without a manufactured reason (`permission denied: CORRECT_PASSENGER_MANIFEST`); the branch manager and the finance manager are refused without a fresh reason (pinned); the finance manager is refused moving an entry between unfrozen items with a reason (evidence rule) and without one (object-class guard, pinned); after every refusal the issued booking still has its item and its traveller; both reproduced round trips fail at their first step.

Non-Empty Population Obligation: Prove the issued booking has the item and the frozen entry, the employee holds CREATE_BOOKING_ITEM and not CORRECT_PASSENGER_MANIFEST and can see both, the branch manager holds both, the finance manager at `aal2` holds CORRECT_PASSENGER_MANIFEST and not CREATE_BOOKING_ITEM, and each refused statement targets a visible item or entry.

Mutation Obligation: Replace `app.manifest_is_frozen` with a mutant that never reports `issued` as frozen, positively inspect the installed definition and its answer, and show that both reproduced escapes land again (the item leaves and the entry leaves without a correction); restore the original and prove its definition is byte-identical, so the one helper is shown to own every rule. A failed installation is HARNESS ERROR, never a killed mutant.

Post-Implementation Proof Obligation: Focused test, clean reset, pgTAP A/B, six HTTP suites, smoke, installed/restored mutation, generated artifacts, fresh Primary evidence, parity and repository Gate on final bytes.

## Implementation Steps

1. **Check** that `supabase/migrations/20260926140000_manifest_freeze_cannot_be_left.sql` is absent. If absent, create one LF migration that creates `app.manifest_is_frozen(text, boolean)` (SQL, IMMUTABLE, empty `search_path`, EXECUTE revoked from public) returning the freeze set PAX-5 defines; replaces `app.enforce_booking_item_passenger_lifecycle()` with its current installed definition except that the inline set is replaced by the helper and one branch is added that treats a row leaving a frozen item as a correction (CORRECT_PASSENGER_MANIFEST, fresh reason, server stamp); replaces `app.enforce_booking_item_lifecycle()` with its current installed definition plus one refusal when an item's current booking is frozen; and replaces `app.guard_write_capability()` with its current installed definition plus exactly one case in the `booking_item_passengers` correction condition (the item changes, the OLD item's booking is frozen by the helper, and a fresh non-empty reason is supplied). Change no trigger, grant, policy, permission, column or other function. If the target exists with different bytes or an installed source differs from local, stop.
2. **Check** that `supabase/tests/129_manifest_freeze_cannot_be_left_test.sql` is absent. If absent, create one LF transaction-rolled-back pgTAP file with a closed-vocabulary `-- ATTACK-CLASSES:` line and an exact `plan(N)` proving the Positive and Negative Test Design, the Non-Empty Population Obligation and the Mutation Obligation. If the target exists with different bytes, stop.
3. **Check** whether `bookings` remains `NOT-RECORDED` and PAX-9 and BOOK-10 are absent from the register. If so, register PAX-9 (Medium) as fixed by this change and BOOK-10 (Medium, OPEN: the booking lifecycle rules of `app.advance_booking` do not hold on the direct status door), set only `bookings` to `AUDITED-OPEN` / `ADVERSARIAL` with findings PAX-9, BOOK-10, and mechanically update Batch-6 coverage to 24/77. Leave every other finding unchanged. If the current record conflicts, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run clean local reset, focused test, pgTAP Pass A, six declared HTTP suites, pgTAP Pass B without reset, `scripts/verify_database.sql`, plan sum, installed mutation proof, the changed-definition comparisons against Primary's current raw definitions, API-contract and map generators, scope, `git diff --check`, repository consistency and parity readiness. Record actual counts, exits and exact SHA-256 hashes. Treat only undeployed Primary/manifest/parity drift as expected at this boundary.
5. **Check** that exact owner authorization for the migration and permanent-test SHA-256 values is recorded in the Execution Log. If absent, stop after Step 4 and present current HEAD, the exact 64-character hashes, fresh full Primary baseline, predicted structural delta and exact Primary write. CR approval does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20260926140000_manifest_freeze_cannot_be_left`. If absent and separately authorized, immediately re-read HEAD, hashes, project identity, full ordered Primary ledger, target absence, both installed enforcer md5s, helper absence, and zero bookings, items and manifest links. On exact match apply only the authorized migration. Normalize only its newly inserted ledger row if the connector assigns a temporary version. Read fresh full ledger, function and all ten structural surfaces, the changed definitions, security modes and EXECUTE ACLs. Never contact Secondary.
7. **Check** that fresh Primary evidence contains the unique new migration. If so, update `reports/evidence/primary-ledger-evidence.json` and the manifest only from measured Primary facts; regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` with canonical generators. Run ledger, parity-evidence, repository consistency and `git diff --check`. If Primary is unproven, stop.
8. **Check** for a `Post-deploy local certification` Execution Log entry. If absent, run canonical `-Finish` and require `LOCAL_CERTIFY: READY`; independently Review the committed implementation and every acceptance item. After `Verdict: Confirmed Complete`, set Runtime Checkpoint DONE, transition Complete and clear the manifest pointer. Publish the exact committed candidate, require exact-SHA candidate CI, promote the same accepted SHA, run `-Certify` for `REMOTE_CERTIFY: READY`, verify synchronized clean refs, and remove permitted scratch files. Do not start Slice 24.

## Acceptance Criteria

- [ ] Nobody can move a booking item off a booking whose manifest has frozen, and only a CORRECT_PASSENGER_MANIFEST holder (including a finance manager) with a fresh reason can move a manifest entry off a frozen item, stamped; a finance manager gains no relocation door between unfrozen items; each refusal is pinned to its message and the issued booking keeps its item and traveller.
- [ ] Re-parenting between unfrozen bookings and items, moving into a frozen booking or item, and the PAX-5 and PAX-7 correction paths keep working; the helper is the one definition the enforcers and the guard read, and `authenticated` cannot execute it.
- [ ] PAX-9 is fixed; BOOK-10 is a separate OPEN finding; `bookings` is `AUDITED-OPEN` / `ADVERSARIAL` and coverage is 24/77; every other finding is untouched.
- [ ] Migration, test, generated artifacts, local and fresh Primary evidence agree, with no out-of-scope file changes.

## Execution Log

None yet.

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

EARN IT: the freeze the owner decided in SPEC-223 (and PAX-5 before it) was defeated end to end by moving an item or an entry out, changing it, and moving it back, with no authority, reason or stamp. WORTH IT: two conditions on existing enforcers, one case on the existing guard door, and one helper that removes a would-be second definition of frozen; no schema, grant or trigger change. Revised before approval (owner pre-approval review): the first Draft let a branch manager make the reasoned removal but not a finance manager, whom canon 28 grants the correction; the guard now offers the capability for a frozen departure only, and a finance manager's relocation between unfrozen items is refused both with a reason (evidence rule) and without one (object-class guard). Rejected: a sticky per-row freeze stamp (needs a write at issue time into rows whose guard the issuing finance manager cannot pass, SPEC-223's measured obstacle); allowing an item to leave a frozen booking with CORRECT_PASSENGER_MANIFEST (items carry no reason, so the correction could not be attributed); offering CORRECT_PASSENGER_MANIFEST for ANY re-parent with a reason (would give a finance manager a general relocation door). BOOK-10 is registered separately, not absorbed. PAX-8, ENTRY-1, CAMP-4, PAY-3 and PAY-4 are untouched.
