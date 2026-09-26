# Change Request — SPEC-224

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make the PAX-5 frozen passenger manifest immutable in membership on every door: once a booking's manifest has frozen, no traveller joins or leaves it — by an item moving in or out, an entry moving in or out, or a new entry — except through the existing attributed correction (CORRECT_PASSENGER_MANIFEST, a fresh reason, a server stamp) that every correction holder can reach; correction evidence can never be supplied at birth; and every rule reads one definition of frozen.

## Business Reason

Batch 6 Slice 23 selected `bookings` live at Exposure 10, coverage 234; `branches` was runner-up at 10/578. `bookings.booking_status_code` freezes every passenger manifest: the PAX-5 owner decision says a passenger manifest becomes immutable at issue and a post-issue correction is a deliberate, attributed, audited act requiring its own capability (canon 28), and PAX-7 (SPEC-223) froze the ticketed identity. The implementation priced only the swap. In rolled-back local transactions an `employee` at `aal2` holding CREATE_BOOKING_ITEM and not CORRECT_PASSENGER_MANIFEST, refused the swap on an issued manifest (`permission denied: CORRECT_PASSENGER_MANIFEST`), changed its membership six other ways: (1) moved the issued booking's item to a draft booking, swapped the traveller and moved it back; (2) moved a frozen entry to a draft item, swapped and moved it back — each leaving the issued booking naming `Mona Second` with no reason or stamp; (3) INSERTed a new traveller into the issued item (`booking_item_passenger_linked`, reason NULL, no stamp); (4) moved an entry from a draft item onto the issued item (`booking_item_passenger_replaced`, reason NULL, no stamp); (5) moved a draft item carrying a traveller into the issued booking, adding that traveller; and (6) INSERTed an entry carrying forged correction evidence — "corrected by" the branch manager, dated 2020, with a reason — which persisted. Causes: both enforcers judge only where a row or item moves TO; the INSERT arm never asks whether the target manifest has frozen and accepts caller-supplied correction evidence; and the event producer records a reason only on UPDATE. Exposure today is nil: Primary holds 0 bookings, 0 booking items and 0 manifest links.

## Risks

- Five functions are restated or added; each must differ from its installed definition only by the measured additions.
- Following BOOK-1 (the manifest enforcer has no session-less exemption, pinned by `74_...` assertion 3), a session-less INSERT into a frozen manifest is refused too, so a migration or import builds a frozen manifest by linking travellers before issuing; Tests 114 and 128 build their fixtures in the old order and must be reordered, with no assertion changed.
- Pre-freeze manifest work (INSERT, re-parenting between unfrozen items and bookings) and adding an EMPTY service to an issued booking must keep working, and a finance manager must gain no general relocation door.
- Primary deployment adds one function and changes four; it requires separate exact-byte owner authorization after local proof.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-224-manifest-freeze-cannot-be-left.md`
- `supabase/migrations/20260926140000_manifest_freeze_cannot_be_left.sql`
- `supabase/tests/129_manifest_freeze_cannot_be_left_test.sql`
- `supabase/tests/114_passenger_manifest_freeze_and_events_test.sql`
- `supabase/tests/128_frozen_traveller_identity_snapshot_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/20260909132000_the_manifest_freezes_when_the_ticket_is_issued.sql`
- `supabase/migrations/20260909133000_a_manifest_change_is_a_business_event.sql`
- `supabase/migrations/20260926130000_frozen_traveller_identity_snapshot.sql`
- `supabase/migrations/202607059400_the_parents_state_is_a_rule_on_every_door.sql`
- `supabase/tests/74_booking_item_lifecycle_test.sql`
- `supabase/tests/104_booking_item_passenger_manifest_surface_test.sql`
- `supabase/tests/105_booking_item_service_door_test.sql`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `_ORVION_CANONICAL/31_schema_draft.md`
- `scripts/verify_database.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/28_permissions_matrix.md` (the passenger-manifest freeze rule); `_ORVION_CANONICAL/27_event_catalog.md` (`booking_item_passenger_linked`, `_replaced`, `_removed`); `_ORVION_CANONICAL/26_state_machines.md` (Booking); the PAX-5 owner decision in `supabase/migrations/20260909132000_the_manifest_freezes_when_the_ticket_is_issued.sql`
- Current local `app.enforce_booking_item_lifecycle`, `app.enforce_booking_item_passenger_lifecycle`, `app.guard_write_capability`, `app.record_manifest_change_event`, `app.create_booking_item`, `app.advance_booking`, `app.map_outcomes_to_conversions`; `supabase/tests/74_booking_item_lifecycle_test.sql`, `supabase/tests/114_passenger_manifest_freeze_and_events_test.sql` and `supabase/tests/128_frozen_traveller_identity_snapshot_test.sql`
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
| One definition of frozen, `app.manifest_is_frozen(status, archived)` | both lifecycle enforcers; `app.guard_write_capability` | VERIFY | The manifest enforcer's inline set (an archived booking, or `issued, reissue, refunded, void, completed`) moves into the helper unchanged; all callers read it. Measured: IMMUTABLE SQL, SECURITY INVOKER, empty `search_path`, ACL `{postgres=X/postgres}`; `authenticated` and `anon` have no EXECUTE, and it lives in `app`, not the API schema, so it is no client RPC. All callers are SECURITY DEFINER. |
| Items: none leaves a frozen booking; none carrying travellers joins one | direct `booking_items` UPDATE; `app.create_booking_item` | VERIFY | No function re-parents an item. Prototype: the employee, a branch manager and the platform path were refused moving the issued booking's item out; a draft item carrying a traveller was refused joining the issued booking (`a booking item carrying passengers cannot join a booking whose passenger manifest has frozen`); an EMPTY item still joined it and draft items still moved between draft bookings. Adding a service to an issued booking is `app.create_booking_item`'s existing, separately owned behaviour and changes no one's manifest membership; any traveller later linked to it pays the manifest's own correction. An item carries no reason, so no attributed form exists to allow. |
| Manifest entries: joining (INSERT or move in) or leaving (move out) a frozen manifest is the attributed correction; no correction evidence at birth | direct `booking_item_passengers` INSERT/UPDATE; `app.link_passenger_to_booking_item`; `app.correct_passenger_manifest` | VERIFY | Charged after the existing attach checks, so a closed booking keeps its refusal message. Prototype: the employee was refused every insertion into, move onto and move off a frozen item, with or without a manufactured reason (`permission denied: CORRECT_PASSENGER_MANIFEST`); a branch manager and a finance manager were refused without a fresh reason (`joining or leaving a frozen passenger manifest requires its own reason`) and with one landed, stamped with that actor and time. A forged-evidence INSERT on a draft item was refused (`manifest correction evidence is not editable on its own`); an ordinary pre-issue INSERT still landed with no stamp. A session-less move off a frozen item was refused like a session-less swap; a session-less INSERT into a frozen manifest is refused too (BOOK-1), and a session-less INSERT before issue still lands. |
| The guard offers CORRECT_PASSENGER_MANIFEST for a frozen join or leave carrying a fresh reason | `app.guard_write_capability` PAX-5/PAX-7 correction condition | VERIFY | Canon 28 grants the correction to `finance_manager`, which lacks CREATE_BOOKING_ITEM. The UPDATE condition gains one case (the item changes and either endpoint's booking is frozen) and an INSERT case is added (target frozen, non-empty reason); both look up only the caller's tenant, so they answer nothing about another tenant. They only widen who reaches the enforcer. Containment, measured: a finance manager inserting on or moving between UNFROZEN items was refused with a reason (evidence rule) and without one by the object-class guard (`permission denied: one of CREATE_BOOKING_ITEM is required to write booking_item_passengers`). |
| A post-issue addition records its reason | `app.record_manifest_change_event` (the single producer) | VERIFY | The producer passes `passenger_correction_reason` on INSERT as well as UPDATE; nothing else changes. Prototype: the finance manager's insertion recorded `booking_item_passenger_linked` with its reason; moves recorded `booking_item_passenger_replaced` with theirs; a pre-issue insertion still records a NULL reason. |
| Protected tests | `74_...` assertion 3 (no `auth.uid()` in either enforcer); Tests 114 and 128 fixtures | WRITE | The enforcers still never call `auth.uid()`. Tests 114 and 128 inserted travellers directly into already-issued (and void) bookings on the session-less path; they now create those bookings as `draft`, link, then set the final status — no assertion changes. Measured under the prototype: reordered 114 29/29 and 128 43/43; every other file passed. |
| Everything else | the six HTTP suites; the rest of the suite; `scripts/verify_database.sql`; API contract | VERIFY | Prototype on a clean reset: HTTP 33 + 120 + 40 + 74 + 122 + 60 = 449 passed, 0 failed; `verify_database.sql` ALL CHECKS PASSED; API-contract generator output identical; no seed file exists. PAX-5 swap still refused for the employee and allowed for a holder with a reason; a post-freeze profile rename still leaves the frozen identity unchanged (PAX-7). |
| Booking lifecycle rules on the direct door | `app.advance_booking`; `app.map_outcomes_to_conversions` | UNAFFECTED | Separately reproduced as BOOK-10 (Medium, OPEN): with a per-user deny on ALLOW_ISSUE_WITH_NEGATIVE_BALANCE a branch manager was refused by the RPC (customer owes 5000 EGP) and issued by direct UPDATE; direct issues record no `booking_issued` (the conversion mapper's `ticket_issued` source) and no risk event. Different invariant and mechanism with its own design choice (a direct cancellation cannot carry the required reason), so registered, not repaired here. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 7 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused test, pgTAP A/B, six HTTP suites, smoke and installed mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Tests 114 and 128 build their frozen manifests in the order the rule requires | BEFORE_IRREVERSIBLE_ACTION | Step 1 | Step 3 | Step 5 |
| Slice-23 findings and 24/77 disposition describe local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Manifest and Primary ledger/function/structure agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 8 | Step 9 |
| API contract and map match generators | BEFORE_COMPLETION | Step 1 | Step 8 | Step 9 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `app.enforce_booking_item_lifecycle` owns which booking an item may attach to; `app.enforce_booking_item_passenger_lifecycle` owns the freeze and the post-issue correction (CORRECT_PASSENGER_MANIFEST, fresh reason, server stamp); `app.guard_write_capability` already offers that capability for an attributed correction; `app.record_manifest_change_event` is the single manifest-event producer. Reuse all four: the enforcers gain the missing questions (what is left, what is joined, whether a new entry joins a frozen manifest, whether evidence is supplied at birth), the guard offers the same capability for those corrections, the producer carries the reason on INSERT, and the freeze set moves into one helper they all read. No new permission, column, event type or trigger.

Added Property: once a booking's manifest has frozen, its membership changes only by an attributed correction that every CORRECT_PASSENGER_MANIFEST holder can make and that records its reason, actor and time; an item never carries travellers in or out of it; correction evidence exists only where a correction happened.

Causal Negative: An employee without CORRECT_PASSENGER_MANIFEST, refused the swap on an issued manifest, changed who was on it by moving its item out and back, by moving an entry out and back, by inserting a new traveller, by moving an entry onto it, and by moving a traveller-carrying item into the booking, each with no reason or stamp; and inserted an entry carrying a forged "corrected by the manager" record. Every probe rolled back.

Positive Test Design: Pre-issue INSERT and re-parenting between unfrozen items and bookings work with no stamp; an empty item joins an issued booking; a branch manager and a finance manager each add, move in and move out an entry with a fresh reason, stamped with that actor, and the linked/replaced event carries the reason; the PAX-5 swap and PAX-7 correction still land for a holder; a session-less INSERT before issue still lands.

Negative Test Design: The employee is refused every insertion into, move onto and move off a frozen item, with or without a manufactured reason (`permission denied: CORRECT_PASSENGER_MANIFEST`); correction holders are refused without a fresh reason (pinned); a forged-evidence INSERT is refused (pinned); a finance manager is refused inserting on or moving between unfrozen items with a reason (evidence rule) and without one (object-class guard, pinned); nobody moves an item off a frozen booking or a traveller-carrying item onto one (pinned); session-less moves off and INSERTs into a frozen manifest are refused; after every refusal the issued booking's membership is unchanged; `74_...`'s no-`auth.uid()` pin still holds.

Non-Empty Population Obligation: Prove the issued booking has its item and frozen entries, the employee holds CREATE_BOOKING_ITEM and not CORRECT_PASSENGER_MANIFEST and can see them, the branch manager holds both, the finance manager at `aal2` holds CORRECT_PASSENGER_MANIFEST and not CREATE_BOOKING_ITEM, and each refused statement targets a visible item or entry.

Mutation Obligation: Replace `app.manifest_is_frozen` with a mutant that never reports `issued` as frozen, positively inspect its definition and its answer, and show that every operation it owns reopens for the employee without a reason — inserting into the issued item, moving an entry off and back onto it, swapping its traveller, moving its item out, and moving a traveller-carrying item in; restore the original and prove its definition is byte-identical. A failed installation or a fixture collision is HARNESS ERROR, never a killed mutant.

Post-Implementation Proof Obligation: Focused test, clean reset, pgTAP A/B, six HTTP suites, smoke, installed/restored mutation, generated artifacts, fresh Primary evidence, parity and repository Gate on final bytes.

## Implementation Steps

1. **Check** that `supabase/migrations/20260926140000_manifest_freeze_cannot_be_left.sql` is absent. If absent, create one LF migration that: creates `app.manifest_is_frozen(text, boolean)` (SQL, IMMUTABLE, empty `search_path`, EXECUTE revoked from public) returning the PAX-5 freeze set; replaces `app.enforce_booking_item_passenger_lifecycle()` with its installed definition plus the helper in place of the inline set, one UPDATE case marking a move that joins or leaves a frozen manifest, and — after the existing attach checks — the INSERT rule (frozen target: correction; otherwise no correction evidence) and the correction charge (CORRECT_PASSENGER_MANIFEST, fresh reason, server stamp), with no reference to `auth.uid()`; replaces `app.enforce_booking_item_lifecycle()` with its installed definition plus the refusal to leave a frozen booking and to join one while carrying travellers; replaces `app.guard_write_capability()` with its installed definition plus exactly the frozen-join/leave UPDATE case and the frozen-INSERT case in its `booking_item_passengers` correction offer; and replaces `app.record_manifest_change_event()` with its installed definition passing the correction reason on INSERT as well as UPDATE. Change no trigger, grant, policy, permission, column or other function. If the target exists with different bytes or an installed source differs from local, stop.
2. **Check** that `supabase/tests/129_manifest_freeze_cannot_be_left_test.sql` is absent. If absent, create one LF transaction-rolled-back pgTAP file with a closed-vocabulary `-- ATTACK-CLASSES:` line and an exact `plan(N)` proving the Positive and Negative Test Design, the Non-Empty Population Obligation and the Mutation Obligation. If the target exists with different bytes, stop.
3. **Check** whether Tests 114 and 128 still create their frozen bookings in a frozen status before linking travellers. If so, change only that fixture order in each — create those bookings as `draft`, then after the manifest inserts set the final status on the session-less path, with one comment citing SPEC-224 — leaving every assertion, count and `plan(N)` unchanged.
4. **Check** whether `bookings` remains `NOT-RECORDED` and PAX-9 and BOOK-10 are absent from the register. If so, register PAX-9 (Medium) as fixed by this change and BOOK-10 (Medium, OPEN: the booking lifecycle rules of `app.advance_booking` do not hold on the direct status door), set only `bookings` to `AUDITED-OPEN` / `ADVERSARIAL` with findings PAX-9, BOOK-10, and mechanically update Batch-6 coverage to 24/77. Leave every other finding unchanged. If the current record conflicts, stop.
5. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run clean local reset, focused tests (129, 114, 128, 74), pgTAP Pass A, six declared HTTP suites, pgTAP Pass B without reset, `scripts/verify_database.sql`, plan sum, installed mutation proof, the changed-definition comparisons against Primary's current raw definitions, API-contract and map generators, scope, `git diff --check`, repository consistency and parity readiness. Record actual counts, exits and exact SHA-256 hashes. Treat only undeployed Primary/manifest/parity drift as expected at this boundary.
6. **Check** that exact owner authorization for the migration and all three test SHA-256 values is recorded in the Execution Log. If absent, stop after Step 5 and present current HEAD, the exact 64-character hashes, fresh full Primary baseline, predicted structural delta and exact Primary write. CR approval does not authorize deployment.
7. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20260926140000_manifest_freeze_cannot_be_left`. If absent and separately authorized, immediately re-read HEAD, hashes, project identity, full ordered Primary ledger, target absence, the four installed definitions' md5s, helper absence, and zero bookings, items and manifest links. On exact match apply only the authorized migration. Normalize only its newly inserted ledger row if the connector assigns a temporary version. Read fresh full ledger, function and all ten structural surfaces, the changed definitions, security modes and EXECUTE ACLs. Never contact Secondary.
8. **Check** that fresh Primary evidence contains the unique new migration. If so, update `reports/evidence/primary-ledger-evidence.json` and the manifest only from measured Primary facts; regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` with canonical generators. Run ledger, parity-evidence, repository consistency and `git diff --check`. If Primary is unproven, stop.
9. **Check** for a `Post-deploy local certification` Execution Log entry. If absent, run canonical `-Finish` and require `LOCAL_CERTIFY: READY`; independently Review the committed implementation and every acceptance item. After `Verdict: Confirmed Complete`, set Runtime Checkpoint DONE, transition Complete and clear the manifest pointer. Publish the exact committed candidate, require exact-SHA candidate CI, promote the same accepted SHA, run `-Certify` for `REMOTE_CERTIFY: READY`, verify synchronized clean refs, and remove permitted scratch files. Do not start Slice 24.

## Acceptance Criteria

- [ ] Once a booking's manifest has frozen, no traveller joins or leaves it — by item, entry move or INSERT, on any path — except by CORRECT_PASSENGER_MANIFEST with a fresh reason, server-stamped, which a finance manager can make; an item never carries travellers in or out; each refusal is pinned to its message and the issued booking's membership is unchanged.
- [ ] Pre-issue manifest work, re-parenting between unfrozen items and bookings, an empty item joining an issued booking, and the PAX-5 and PAX-7 correction paths keep working; correction evidence cannot be supplied at birth; a finance manager gains no door between unfrozen items; post-issue additions record their reason in the single event producer; the helper is the one definition every caller reads and `authenticated` cannot execute it; `74_...`'s pin still holds.
- [ ] PAX-9 is fixed; BOOK-10 is a separate OPEN finding; `bookings` is `AUDITED-OPEN` / `ADVERSARIAL` and coverage is 24/77; Tests 114 and 128 differ only in fixture order; every other finding is untouched.
- [ ] Migration, tests, generated artifacts, local and fresh Primary evidence agree, with no out-of-scope file changes.

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

EARN IT: the manifest the PAX-5 owner decision made immutable at issue, and whose ticketed identity SPEC-223 froze, could have its membership changed six ways by a caller without the correction capability, with no reason, actor or event reason, and a "corrected by the manager" record could be forged at birth. WORTH IT: conditions on the four existing owners and one helper that prevents a second definition of frozen; no schema, grant, trigger or permission change. Revision history before approval (owner pre-approval reviews): Draft `de1ad8e` closed the two outbound escapes; `6367b4f` let a finance manager reach the outbound correction; this revision adds the inbound directions (INSERT, entry move-in, item join with travellers), evidence integrity at birth, the reason on post-issue additions, and — because `74_...` pins BOOK-1's no-session-less-exemption principle — applies the INSERT rule to the platform path too, which is why Tests 114 and 128 join the scope for a fixture reorder. Classification of an item joining an issued booking: with travellers it is PAX-9 (it changes who is on the frozen manifest); EMPTY it is `app.create_booking_item`'s existing post-issue service addition, left as it is. Rejected: a sticky per-row freeze stamp (needs an issue-time write the finance-manager issuer's guard would refuse, SPEC-223's measured obstacle); a session-less INSERT exemption (would reverse BOOK-1 and `74_...`, or evade its pin); allowing items to leave or join with CORRECT_PASSENGER_MANIFEST (items carry no reason); offering the capability for any re-parent with a reason (a general relocation door for finance). BOOK-10 is registered separately. PAX-8, ENTRY-1, CAMP-4, PAY-3 and PAY-4 are untouched.
