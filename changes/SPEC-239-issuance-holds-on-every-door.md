# Change Request — SPEC-239

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Close BOOK-10 for issuance. Make one table trigger, `bookings_enforce_lifecycle`, the single authority for the rules of `app.advance_booking` that a table write can express, and the single producer of `booking_issued` and `booking_item_risk_flag_created`. Remove the RPC's own copies, so each rule and each event has one owner. Prove that a genuine issuance on every legal door obeys the negative-balance override, records its risk flag and reaches the `ticket_issued` Google Ads conversion exactly once, and that an issuance the RPC refuses is refused on the door by the same control. This is the third contract of the Phase-8 Activation Closure and closes `MASTER_INTEGRATION_CATALOG.md` §2b item 1. Record BOOK-11 and BOOK-12, found on the way and not repaired, and close ENTRY-1's `bookings` instance.

## Business Reason

The manifest's next capability is the Phase-8 Activation Closure, and BOOK-10's trigger has fired. `ticket_issued` is one of the five conversions, and the conversion system may not be called live while a legal issuance produces none, or while the same issuance is refused on one door and allowed on the other.

- **The intended rules.** Canon 26: `in_progress -> issued` and `reissue -> issued` are issuance, and a booking starts at `draft`. Canon 28 and ADR-0020: issuance costs ISSUE_BOOKING; issuing before full collection also costs ALLOW_ISSUE_WITH_NEGATIVE_BALANCE and records `booking_item_risk_flag_created` with the permission used and the customer balance snapshot. ADR-0021: `app.customer_balance` is the one definition of that balance. ADR-0024: every rule an RPC enforces must also hold on the table door. `app.map_outcomes_to_conversions` maps `booking_issued -> ticket_issued`.
- **The door is legal.** SEC-1 (revoking direct DML) is an open owner decision, `authenticated` holds UPDATE and INSERT on `bookings`, and `app.status_transitions` publishes exactly the RPC's sixteen edges to the table door, each under its permission, through `app.enforce_status_transition`. So ADR-0024 applies; nothing here restricts the door.
- **BOOK-10 (Medium, reproduced, latent).** Measured on the local stack at `2496591`, in rolled-back transactions, with a consented Google Ads click on every lead. The owner invoiced three bookings without collecting (the customer owes 5000 EGP on each) and took seven to `in_progress`:

  | Act | Sanctioned RPC | Direct door |
  | --- | --- | --- |
  | Owner issues an owed booking | 1 `booking_issued`, 1 risk flag, 1 `ticket_issued` | — |
  | `branch_manager` holding ISSUE_BOOKING, per-user DENY on the override, issues an owed booking | refused `permission denied: ALLOW_ISSUE_WITH_NEGATIVE_BALANCE` | **issued**, no event, no risk flag, no conversion |
  | Owner issues a booking nothing is owed on | — | issued, **no `booking_issued`, no `ticket_issued`** |
  | Session-less (platform) issue | — | issued, no event |
  | Issue, or cancel, an archived booking | refused `booking is archived` | **issued**; **cancelled** |
  | `employee` with CREATE_BOOKING and not ISSUE_BOOKING INSERTs a booking at `issued` | — | **created issued**: no transition, no permission, no issuance event (ENTRY-1) |
  | `employee` without ISSUE_BOOKING issues by UPDATE (control) | — | refused `permission denied: ISSUE_BOOKING` |

- **Every other issuance consequence was measured, not assumed.** The manifest freeze (`app.manifest_is_frozen`), the item and passenger guards, and finance approval all read the stored status, so they already hold on either door. ISSUE_BOOKING and step-up are charged by `app.enforce_status_transition` on both. `booking_issued` has one reader, the mapper; the risk flag has none but the timeline.
- **Exposure.** Primary holds 0 bookings, 0 per-user denies and 0 offline conversions, and no delivery workflow exists. The defect is latent until the first tenant issues.
- **The repair is not SPEC-237's or SPEC-238's shape copied.** Issuance is not only an event: it carries an authorization, a refusal and a derived snapshot, and the event must not be recorded for an issuance the rules refuse. So the rules and the events move together into one function, in one trigger:
  - **AFTER INSERT OR UPDATE OF `booking_status_code`, row-level, immediate.** AFTER, so it judges a row that the state machine, capability and step-up triggers have already passed; the refusal order is the RPC's. Immediate, not deferred as PAY-3 needed, because nothing issuance reads is written after the booking in the same transaction.
  - **Entry (ENTRY-1).** A signed-in caller creates a booking at `draft`, the state `app.create_booking` writes. Session-less paths are exempt, LEAD-2's rule, because `app.enforce_status_transition` already exempts them from the whole graph.
  - **Archived.** An archived booking's status does not move. This is the RPC's rule for every transition, moved whole: splitting it by transition would leave two authorities for one invariant. It holds on every path, being integrity (ADR-0025).
  - **Issuance,** on entry into `issued` only. The balance of the booking as it stood before the write comes from `app.customer_balance`. If any currency is owed, a signed-in caller must hold the override. Then `booking_issued` is recorded with the RPC's payload keys and, when owed and signed in, the risk flag with the permission used and the snapshot. The override and its risk record are authorization, so a session-less path is exempt from both (ADR-0025); `booking_issued` is recorded on every path.
  - **SECURITY INVOKER,** unlike the SPEC-237/238 emitters. The balance the override is judged on stays exactly the one the RPC judged: the caller's, since the RPC is invoker too. `app.record_event` is SECURITY DEFINER and owns the actor and time.
  - **The RPC** loses its archived check, its balance block and its issuance emission, and hands the trigger its reason through SPEC-237's transaction-local `app.transition_reason`, which the trigger consumes. It keeps its transition table, the cancellation reason, the stamps and the other eight transition events.
- **Found on the way.** The trigger first read the balance from `NEW`, and a manager rebinding the booking to a customer who owes nothing in the same UPDATE escaped the override. It now reads `OLD`, what the RPC reads, and assertion 9 and mutant M-I pin it. Rebinding first and issuing in a second statement escapes the override **on the RPC too**, so it is not door parity: it is BOOK-12, recorded and not repaired, because its repair needs a business rule on when a booking's customer may change.
- **Not in this contract.** BOOK-11: the cancellation reason, the `cancelled_at`/`completed_at` stamps and the eight non-issuance transition events on the door. None is a conversion source, and each carries BOOK-10's recorded design choice. PH8-4, PH8-9 and the delivery workflow follow.

## Risks

- **An issuance recorded twice would be a ticket uploaded twice.** Mitigated by three things:
  - The RPC no longer emits `booking_issued` or the risk flag, and the trigger is their only producer. A census of every function body found no other writer of either code, and `app.advance_booking` is the only function that writes `booking_status_code`.
  - `source_event_seq` is unique on `offline_conversions`.
  - Test 141 asserts one event per issuance on every door, and mutant M-A, which restores the RPC's emission, is killed.
- **A refusal moved into a trigger could fire where it should not.** Mitigated:
  - The override is demanded only on entry into `issued`, only when a currency is owed, and only of a signed-in caller (assertions 10 and 19; mutants M-B and M-H).
  - Remaining in `issued` and unrelated edits fire nothing (assertion 17; mutant M-C).
  - The entry rule refuses only a non-`draft` birth by a signed-in caller (assertions 15 and 16; mutant M-D).
- **The archived rule now holds on door transitions other than issuance.** Intended: it is the RPC's rule for every transition, and ADR-0024 requires it on the door. No fixture, seed, HTTP journey or function moves an archived booking's status; the prototype's full suite and all six HTTP suites pass. One refusal message changes order: an archived booking asked for a transition the caller may not make is now refused by the permission first, where the RPC used to say `booking is archived` first. No test pins that order.
- **`reissue -> issued` is issuance again.** Preserved, not invented: canon 26, the RPC's transition table and ADR-0020 all treat it so, and the mapper makes one `ticket_issued` per `booking_issued`. Whether Google should count a reissued ticket as a second Ticket Issued conversion is an owner question for the delivery contract, recorded in Notes; this contract does not change it.
- **Tests pinned to the old shape.** None. The prototype's full suite passes unchanged, including Tests 32, 54, 114, 128, 129 and 137, which issue bookings on the door or the RPC.
- **Primary deployment adds one function and one trigger and replaces one function body in production.** It requires separate exact-byte owner authorization (Gate 2). Approving this contract does not authorize it.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-239-issuance-holds-on-every-door.md`
- `supabase/migrations/20260929120000_issuance_holds_on_every_door.sql`
- `supabase/tests/141_issuance_holds_on_every_door_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_INTEGRATION_CATALOG.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607046600_advance_booking_issue.sql`
- `supabase/migrations/202607046700_advance_booking_cancel_void.sql`
- `supabase/migrations/202607046800_advance_booking_refund_reissue.sql`
- `supabase/migrations/20260928160000_a_qualified_lead_and_a_booking_are_recorded_on_every_door.sql`
- `supabase/migrations/20260928180000_a_payment_is_recorded_on_every_door.sql`
- `supabase/tests/32_lifecycle_transition_test.sql`
- `supabase/tests/54_transition_permission_parity_test.sql`
- `supabase/tests/114_passenger_manifest_freeze_and_events_test.sql`
- `supabase/tests/129_manifest_freeze_cannot_be_left_test.sql`
- `supabase/tests/137_conversion_sources_reach_the_pipeline_test.sql`
- `supabase/tests/139_qualified_lead_and_booking_are_recorded_on_every_door_test.sql`
- `supabase/tests/140_payment_is_recorded_on_every_door_test.sql`
- `_ORVION_CANONICAL/21_offline_conversion_engine.md`
- `_ORVION_CANONICAL/26_state_machines.md`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
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
- `reports/architecture-decision-records.md` ADR-0020, ADR-0021, ADR-0024, ADR-0025
- `_ORVION_CANONICAL/26_state_machines.md` (Booking); `_ORVION_CANONICAL/27_event_catalog.md` (`booking_issued`, `booking_item_risk_flag_created`); `_ORVION_CANONICAL/28_permissions_matrix.md` (booking lifecycle authority)
- `supabase/migrations/20260928160000_a_qualified_lead_and_a_booking_are_recorded_on_every_door.sql` (the reason hand-off reused)
- Current local `app.advance_booking`, `app.enforce_status_transition`, `app.guard_lead_lifecycle`, `app.customer_balance`, `app.authorize`, `app.record_event`, `app.map_outcomes_to_conversions`
- `reports/master/MASTER_GAP_REGISTER.md` (BOOK-10, ENTRY-1, LEAD-2, CONV-8, SEC-1); `reports/master/MASTER_INTEGRATION_CATALOG.md` §2b

## Runtime Checkpoint

Resume Step: 5
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
| `booking_issued` is produced by `bookings_enforce_lifecycle` on every door, and no longer by `app.advance_booking` | `app.map_outcomes_to_conversions` (reads `bookings.lead_id` by `entity_id`); `app.customer_timeline`; `events` readers | VERIFY | The prototype was applied as a real migration on a clean reset in a scratch worktree at `2496591`: migration SHA-256 `a24f93d31d625eeaced0947c97e7c1e7021911eea45286bd8b2553693ff4d917`, Test-141 SHA-256 `9ab9f11ed5885e4f3aef7e44cd42f169481af0c4a30f848c3528a2ea529b10f6`. The RPC path records exactly one event with the same actor, previous and new state, reason, severity and three payload keys as before (assertion 2). |
| `booking_item_risk_flag_created` and the negative-balance override move from the RPC to the trigger | `events` readers (no function reads it); ALLOW_ISSUE_WITH_NEGATIVE_BALANCE holders and denies | VERIFY | The RPC path records one risk flag with the same permission, snapshot and reason (assertion 3); the RPC refuses the denied manager with the same code and message (assertion 7). |
| An archived booking's status does not move on any door; the RPC no longer checks it itself | the RPC's archived refusal; every door transition | VERIFY | The RPC's refusal is unchanged in message and code (assertion 12), and the door's issue and cancellation are now refused (13, 14). No fixture, seed or HTTP journey transitions an archived booking. |
| A signed-in INSERT must be at `draft` | `app.create_booking`; every fixture and HTTP journey that creates a booking | VERIFY | `app.create_booking` writes `draft`. Fixtures that create bookings in other states do so session-less and are exempt; the full suite passes. |
| `app.transition_reason` gains a second consumer | `app.emit_lead_qualified` | VERIFY | Each RPC sets it only immediately before its own single-row UPDATE, and each trigger consumes it. A door issue after an RPC issue carries no inherited reason (assertion 4; mutant M-G). |
| Every other `app.advance_booking` behaviour | the transition table, cancellation reason, stamps and the eight other events; Tests 32, 54, 114, 128, 129, 137 | VERIFY | Unchanged. The full suite passes. |
| Suite, smoke and every HTTP door | full pgTAP; `scripts/verify_database.sql`; all six HTTP suites | VERIFY | On the prototype stack, on a clean reset from a scratch worktree at `2496591`, in `-Finish`'s order: focused Test 141 27/27; pgTAP Pass A 141 files / 2532 assertions PASS (the 2505 existing unchanged, plus 27 new); HTTP suites 33 + 40 + 74 + 122 + 120 + 60 = 449 passed, 0 failed, including every booking lifecycle journey of `verify_lifecycle_branches.ps1`; Pass B without reset 141 / 2532 PASS; smoke `ALL CHECKS PASSED`, exit 0. |
| The generated API surface | `MASTER_API_CONTRACT.md`; `check_database_parity_evidence.ps1` Check L3 | WRITE | No RPC signature, view or table changes: the authority returns `trigger` and is not an endpoint. The regenerated contract changes one line and keeps its totals (79 RPC endpoints, 8 views, 73 tables): `advance_booking`'s row no longer lists ALLOW_ISSUE_WITH_NEGATIVE_BALANCE and counts 4 raises instead of 5, because the override and the archived refusal now live in the table trigger both doors traverse. The generator reads each RPC body, so trigger-held rules do not appear in RPC rows; the `bookings` table-door row is unchanged. It is regenerated in Step 7. |
| Measured state that moves | manifest (`Live state`, suite figure, Last Completed, Active pointer); `primary-ledger-evidence.json`; `ai-map.json`; Checks 5, 7, 15, 19 | WRITE | 237 → 238 migrations, latest `20260929120000`; 140 → 141 files / 2505 → 2532 assertions. Primary values are written only from fresh post-deploy readings. |
| Findings, disposition and the activation list | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; `MASTER_INTEGRATION_CATALOG.md` §2b and the Google Ads registry row; Checks 2, 11, 16, 21, 22, 24, 25 | WRITE | BOOK-10 becomes fixed for issuance. BOOK-11 and BOOK-12 are new and open, each with Owner Decision `—`. ENTRY-1 gains its seventh closed instance. The `bookings` row stays `AUDITED-OPEN` and the `offline_conversions` row stays `PARTIAL`, each gaining Test 141. §2b item 1 closes, and the registry row stops claiming the doors do not produce their events. No other row changes. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused tests, pgTAP A/B, the declared HTTP suite, smoke and in-file mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| BOOK-10, BOOK-11, BOOK-12, ENTRY-1, both disposition rows and §2b accurately describe local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite figure equals the files and plan sum | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: ADR-0024's table-level enforcement in the per-table lifecycle-guard form LEAD-2 set (`app.guard_lead_lifecycle`: the entry state read off the sole creating RPC, with the session-less exemption), combined with SPEC-215's and SPEC-237's single-producer event trigger and SPEC-237's `app.transition_reason` hand-off. The authorization is `app.authorize`, the balance `app.customer_balance`, the event `app.record_event`: no new mechanism. The alternatives were rejected:
- **An event-only trigger, SPEC-237's shape copied:** it would record, and convert, a door issuance the override refuses on the RPC, or one of an archived booking. The event must follow the rules, so it cannot be owned apart from them.
- **A BEFORE guard plus a separate AFTER emitter:** the owed-balance predicate would live twice, once to authorize and once to decide the risk flag, and could drift.
- **A trigger copy of the override while the RPC keeps its own:** two authorities for one rule, the shape this repair removes.
- **Firing the issuance rules on INSERT too, so a booking may be born `issued`:** that would legitimise skipping approval and ISSUE_BOOKING. ENTRY-1 and canon 26 say a booking starts at `draft`.
- **SECURITY DEFINER:** the balance would be read past RLS, changing what the override is judged on relative to the RPC. That is not earned here.
- **A deferred constraint trigger (PAY-3's):** nothing issuance reads arrives later in the transaction, and deferral would refuse at commit, far from the write.
- **Closing the door or revoking UPDATE:** SEC-1 is an open owner decision; `app.status_transitions` publishes the edge deliberately.
- **Promoting ENTRY-1 into `app.status_transitions`:** declined, as SPEC-214 to SPEC-220 declined it: it would change INSERT behaviour on five tables no slice has read.

Added Property: For every `bookings` row on every door: a signed-in creation is at `draft`; an archived booking's status never moves; and every entry into `issued` is refused unless a signed-in caller owing no currency, or holding ALLOW_ISSUE_WITH_NEGATIVE_BALANCE, makes it, judged on the booking as it stood. Each accepted entry records exactly one `booking_issued`, plus one `booking_item_risk_flag_created` when owed and signed in, and yields exactly one `ticket_issued` when its lead is attributed. Remaining in `issued` records nothing. A future writer of `bookings` inherits all of it without knowing it exists.

Causal Negative: On the local stack at `2496591`, in a rolled-back transaction, with a consented Google Ads click on each lead: a `branch_manager` denied ALLOW_ISSUE_WITH_NEGATIVE_BALANCE, refused by `app.advance_booking`, issued the same owed booking by direct UPDATE; an owner's direct issue of an unowed booking recorded no `booking_issued`; the mapper produced no `ticket_issued` for either, while the RPC's issuance produced one; an archived booking was issued by UPDATE; and an `employee` without ISSUE_BOOKING INSERTed a booking born `issued`.

Positive Test Design: As the owner at `aal2`, issue an owed booking through `app.advance_booking` with a reason, then issue an unowed and an owed booking by direct UPDATE. As a manager denied the override, issue an unowed booking by UPDATE. Reissue the first booking through the RPC. As `postgres` with no session, issue the owed booking the manager could not. Create a booking at `draft` as the employee. Then run the real mapper.

Negative Test Design:
- The denied manager is refused an owed issuance on the RPC and on the door by `42501 permission denied: ALLOW_ISSUE_WITH_NEGATIVE_BALANCE`, including when the same UPDATE rebinds the booking to a customer who owes nothing, and the booking stays `in_progress` with no issuance event.
- An archived booking is refused issuance on both doors and cancellation on the door by `booking is archived`.
- An employee without ISSUE_BOOKING is refused a booking born `issued` by the entry rule's own `23514` message.
- A door issue after an RPC issue inherits no reason.
- An unrelated edit and a no-op status write on an issued booking record nothing.
- A further mapper run adds nothing, and every `ticket_issued` is keyed to its own `booking_issued`.

Non-Empty Population Obligation: One tenant, one branch and department, an owner, a `branch_manager` with a per-user deny on ALLOW_ISSUE_WITH_NEGATIVE_BALANCE and an `employee`, two customers, and seven leads, each carrying a consented first-touch Google Ads click. Each lead has a booking taken to `in_progress`, and three of them carry an issued, uncollected 5000 EGP invoice.

Mutation Obligation: In the file, in a savepoint, drop `bookings_enforce_lifecycle`, repeat a door issue, and prove it is silent and the mapper produces nothing; roll back and prove the identical issue is recorded. Out of file, record the md5 of the two function definitions and the trigger definition. Install each mutant, prove the md5 differs, run Test 141, restore, and prove the md5 matches:

| Mutant | Change | Expected to fail |
| --- | --- | --- |
| M-A | `app.advance_booking` keeps its own `booking_issued` emission | assertion 2 |
| M-B | the trigger drops the override | assertion 8 |
| M-C | remaining in `issued` counts as issuance | assertion 17 |
| M-D | the entry rule is removed | assertion 15 |
| M-E | the archived rule is removed | assertion 13 |
| M-F | the risk flag is not recorded | assertion 5 |
| M-G | the reason is not consumed | assertion 4 |
| M-H | the override is demanded of the session-less path | assertion 19 |
| M-I | the balance is judged on `NEW` | assertion 9 |

A mutant whose installation is not proven is a harness error, never a killed mutant.

Post-Implementation Proof Obligation: All of the following, on the final bytes and through canonical `-Finish`:
- the focused test, a clean reset, pgTAP Pass A, the declared HTTP suite, pgTAP Pass B and smoke;
- the in-file and out-of-file mutations and the unrepaired counterfactual;
- the generated artifacts;
- fresh Primary evidence, parity evidence and the Primary ledger check;
- repository consistency and `git diff --check`.

## Implementation Steps

1. **Check** that `supabase/migrations/20260929120000_issuance_holds_on_every_door.sql` is absent. If absent, create it LF with SHA-256 `a24f93d31d625eeaced0947c97e7c1e7021911eea45286bd8b2553693ff4d917`. It holds:
   - `app.enforce_booking_lifecycle()`, `language plpgsql set search_path to ''` (SECURITY INVOKER), with EXECUTE revoked from PUBLIC, holding the entry, archived and issuance rules and the two issuance events;
   - trigger `bookings_enforce_lifecycle`, AFTER INSERT OR UPDATE OF `booking_status_code` ON `public.bookings`, FOR EACH ROW;
   - `app.advance_booking`, identical to its live body except that it no longer selects or checks `is_archived`, no longer computes the balance or records the risk flag, sets `app.transition_reason` before an issuance, and records its own event only when the target is not `issued`.

   It changes no grant, policy, `app.status_transitions` row, other function or mapper. If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/141_issuance_holds_on_every_door_test.sql` is absent. If absent, create it LF with SHA-256 `9ab9f11ed5885e4f3aef7e44cd42f169481af0c4a30f848c3528a2ea529b10f6`. It is one transaction-rolled-back pgTAP file with `select plan(27);`. Its `-- ATTACK-CLASSES:` line reads `DOOR BUSINESS STATE PRIVILEGE OBSERVABILITY REPLAY INPUT=N/A TENANT=N/A AUTH=N/A CONCURRENCY=N/A`, and its header states each `N/A` reason. It implements:
   - the Positive and Negative Test Design;
   - the authority's privilege and trigger shape;
   - the platform path;
   - the in-file Mutation Obligation.

   No existing test changes. If the target carries different content, stop.
3. **Check** whether the BOOK-10 row in `reports/master/MASTER_GAP_REGISTER.md` still reads `**OPEN — reproduced during Slice 23; not absorbed by SPEC-224.**`. If it does, make these changes and nothing else:
   - Add a dated freshness entry and demote the previous one to `Previously:`.
   - Keep every BOOK-10 cell except Status and Updated, and set Updated to `09-29`. Replace the opening bold `OPEN` sentence with a bold statement that SPEC-239 (`20260929120000`) fixed it locally for issuance and the archived rule, pending Primary deployment, with the rest of the lifecycle rules BOOK-11's. Follow it with the mechanism, the measurement, what `141_...` proves, and that the two-statement customer rebinding is BOOK-12, then `Before the repair:` and the original text.
   - Insert **BOOK-11** and then **BOOK-12** after BOOK-10, each Category, Sev `Medium`, Req/Opt `R`, Batch `6`, Mig `—`, Cert `📋`, Status `OPEN`, Owner Decision `—`, Source this contract, dates `09-29`:
     - BOOK-11 carries the measurement of the door's reasonless cancellation and unstamped completion, the cause, that it is not a conversion source, BOOK-10's recorded design choice, its latency and the reopening trigger "before the first production booking";
     - BOOK-12 carries the measurement of the two-statement rebinding on the RPC, the cause, why it is not door parity, that its repair needs a business rule, its latency and the same reopening trigger.
   - Append to the ENTRY-1 row's Status a bold dated note that SPEC-239 closed `bookings`, the seventh instance, with five tables remaining and no generic entry rule, and set its Updated to `09-29`.

   In `reports/master/MASTER_SURFACE_DISPOSITION.md`, add a dated freshness entry and demote the previous one. Then:
   - The `bookings` row stays `AUDITED-OPEN` / `ADVERSARIAL`. Its CR becomes this contract, its findings cell becomes `PAX-9, BOOK-10, BOOK-11, BOOK-12`, and its Next cell records Test 141 closing BOOK-10 with BOOK-11 and BOOK-12 open.
   - The `offline_conversions` row stays `PARTIAL` / `ADVERSARIAL`. Its CR becomes this contract, and its Next cell records BOOK-10 closed, every creation-event axis closed, and the delivery half remaining.
   - Coverage and every other row are unchanged.

   In `reports/master/MASTER_INTEGRATION_CATALOG.md`:
   - in the Google Ads registry row, replace the clause that the table doors do not all produce their events with one stating every legal door now does (§2b item 1, SPEC-237, SPEC-238, SPEC-239), keeping `NOT OPERATIONAL`;
   - extend §2b item 1 with a 2026-09-29 note that BOOK-10 is closed by SPEC-239, BOOK-11 and BOOK-12 are recorded as not conversion blockers, and item 1 is closed.

   If a target already carries different content, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 hashes:
   - a clean local reset and the focused test;
   - pgTAP Pass A, the declared HTTP suite, then pgTAP Pass B without reset;
   - `scripts/verify_database.sql` and the plan sum;
   - the in-file and out-of-file mutation evidence and the unrepaired counterfactual;
   - the API-contract and map generators;
   - the scope check, `git diff --check` and repository consistency.

   Treat only undeployed Primary, manifest and parity drift as expected at this boundary. Read a fresh Primary baseline, read-only:
   - the full ordered ledger and the absence of the target migration;
   - the function and structural surfaces;
   - the tenant, booking, per-user grant, event and offline-conversion counts;
   - the current definition md5 of `app.advance_booking`, and the absence of the authority and trigger;
   - the `bookings` trigger count and Primary's default function ACL for schema `app`.

   Record the predicted structural delta.
5. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 4 and present:
   - the current HEAD and the exact hashes;
   - the fresh Primary baseline and the predicted delta;
   - the exact Primary write requested;
   - the guarded ledger-normalization conditions.

   Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20260929120000_issuance_holds_on_every_door`. If it is absent and deployment is separately authorized:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts and the pre-repair md5.
   - On an exact match, apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row, its stored statement md5 equal to the file's, and no existing target version.
   - Read fresh: the ledger, the function surface and all ten structural surfaces, the authority's security mode, `search_path` and EXECUTE ACL, and the trigger's timing and events.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`:
     - set the `Live state` migration count, latest version, ledger and surface hashes and counts from the same readings;
     - confirm that `supabase/tests` holds 141 files whose literal `plan(N)` values sum to 2532, then set the suite figure to `Suite **141 files / 2532 assertions**`; if either differs, stop;
     - set `Last Completed` to SPEC-239 / BOOK-10, keeping the manifest within 7000 characters.
   - Mark BOOK-10 `DEPLOYED` in the register and change its Cert to `✅`.
   - Regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` (stored LF) with the canonical generators.
   - Set the Runtime Checkpoint to DONE, so that Step 8's `-Finish` runs in VERIFY mode.
   - Run `check_primary_ledger.ps1`, `check_database_parity_evidence.ps1`, repository consistency and `git diff --check`.

   If Primary is unproven, stop.
8. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, do all of the following:
     - transition to Complete;
     - keep `Next capability` as the Phase-8 Activation Closure with Slice 31 paused;
     - clear `Active Change Request`;
     - regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate and require exact-SHA candidate CI.
   - Promote the same accepted SHA, require main CI, and run `-Certify` for `REMOTE_CERTIFY: READY`.
   - Verify synchronized clean refs.

## Acceptance Criteria

- [ ] An owed booking issued through `app.advance_booking`, and bookings issued at the table door by an owner and by a manager, each record exactly one `booking_issued` naming the session's actor, the state it left and the RPC's payload keys, with the RPC's reason on the RPC path and none inherited on the door.
- [ ] An issuance before full collection by an override holder records exactly one `booking_item_risk_flag_created` with the permission used and the balance snapshot, on the RPC and on the door; an unowed issuance records none.
- [ ] A manager denied ALLOW_ISSUE_WITH_NEGATIVE_BALANCE is refused an owed issuance on the RPC and on the door, including when the same UPDATE rebinds the customer, by `42501 permission denied: ALLOW_ISSUE_WITH_NEGATIVE_BALANCE`, and the booking stays `in_progress` with no issuance event.
- [ ] An archived booking is refused issuance on both doors and cancellation on the door by `booking is archived`. A signed-in caller cannot create a booking at any state but `draft`, by the entry rule's own `23514` message, and can at `draft`.
- [ ] Remaining in `issued` and an unrelated edit record nothing; `reissue -> issued` records one more `booking_issued` and, still owed, one more risk flag. A session-less issue records one `booking_issued` with no actor and no override.
- [ ] The real mapper makes exactly one `ticket_issued` per `booking_issued` on the RPC, owner-door, manager-door and platform paths, each keyed to its own event, none for the refused or archived booking, and a further run adds nothing.
- [ ] The authority is SECURITY INVOKER with an empty `search_path`, executable by neither PUBLIC nor `authenticated`, and fires as one AFTER INSERT OR UPDATE ROW trigger.
- [ ] With the trigger dropped in a savepoint, a door issue is silent and produces no conversion, and the rolled-back state records it again. Mutants M-A to M-I are each killed, with their installation and restoration md5-proven. On the unrepaired stack, the decisive assertions of Test 141 fail.
- [ ] BOOK-10 is registered fixed and deployed, BOOK-11 and BOOK-12 are registered open with their trigger, and ENTRY-1 records `bookings` closed. The `bookings` row stays `AUDITED-OPEN`, the `offline_conversions` row stays `PARTIAL`, §2b item 1 is closed, and the Google Ads registry row stays `NOT OPERATIONAL`. Every other row and the Coverage totals are unchanged.
- [ ] The migration and test match their SHA-256 values. Primary, the recorded evidence, the manifest (238 migrations; 141 files / 2532 assertions), the API contract and `ai-map.json` agree.
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-09-29 — Owner approval

The owner approved the exact Draft SHA `7264c98009c6735529e2e19b4051063d66be2ddc` (CR SHA-256 `34c69218f6e19c62055f67b9de45af037baea46f9061f4a1dcb059547ca187e1`) and the frozen ten-path Write Scope. The approval covers Approve, In Progress, Steps 1-4 and full local proof only. Primary remains read-only and requires Human Gate 2.

The approval is bound to two SHA-256 values:
- migration `20260929120000`: `a24f93d31d625eeaced0947c97e7c1e7021911eea45286bd8b2553693ff4d917`;
- Test 141: `9ab9f11ed5885e4f3aef7e44cd42f169481af0c4a30f848c3528a2ea529b10f6`.

The owner decided the two Gate-1 questions:
1. **The archived rule moves whole.** An archived booking may not perform any booking lifecycle status transition, on any legal door, exactly where `app.advance_booking` refuses it. This is intentional parity, not a row freeze: non-lifecycle metadata stays with its existing authorities, and archive and unarchive stay with the existing archive controls.
2. **`reissue -> issued` stays a genuine issuance.** It records another `booking_issued` and yields another internal `ticket_issued` candidate, as the state machine does now. BOOK-10 owns truthful event parity, not Google Ads counting policy, and ORVION's history keeps every issuance.

The owner also directed one record, to be registered and not solved here: a reissue of the same booking must not be assumed to be a second new Google Ads acquisition conversion. The delivery contract must decide the Google `transactionId` for `ticket_issued`, since Data Manager deduplicates and adjusts by `transactionId` within one conversion action. The current `transactionId` implementation, `bookings`, `app.advance_booking`, the lifecycle authority and the source event are not changed for it. Step 3 carries this out as one dated note on the PH8-9 register row, inside the frozen Write Scope. It is the only addition to Step 3's register changes.

Revalidation before approval:
- HEAD was the Draft, a direct child of the certified `2496591`, and the tree was clean.
- `origin/main` was at `2496591`.
- The Draft file hashes to the approved value.
- A read-only evaluation of the committed Draft returned `APPROVAL_EVIDENCE: PASS` (profiles DATABASE and REPOSITORY, one permanent-control path in scope).
- Two mutated copies returned FAIL (a gate at Step 4 inside the red window 1..7) and INDETERMINATE (the Mutation Obligation removed).
- The prototype files in the scratch worktree hash to the two approved values.

### 2026-09-29 — Execution started

The approved ten-path contract entered In Progress at `30814189208935ec37b8438b39d4f1082f431d83`. Resume Step 1. Primary stays read-only until Human Gate 2.

### 2026-09-29 — Steps 1-3 applied (uncommitted until after deployment)

- **Step 1: Applied.** The migration `20260929120000` was created LF, byte-identical to the approved prototype, SHA-256 `a24f93d31d625eeaced0947c97e7c1e7021911eea45286bd8b2553693ff4d917`.
- **Step 2: Applied.** Test 141 was created LF, byte-identical to the approved prototype, SHA-256 `9ab9f11ed5885e4f3aef7e44cd42f169481af0c4a30f848c3528a2ea529b10f6`, `plan(27)`. No existing test changed.
- **Step 3: Applied.** The BOOK-10 precondition text was present exactly once.
  - The register gained a freshness entry. BOOK-10's Status opening was replaced and its Updated cell set to `09-29`; BOOK-11 and BOOK-12 were inserted after it; ENTRY-1 gained its dated note and Updated `09-29`.
  - At the owner's Gate-1 direction, recorded above, PH8-9 gained one dated note, the reissue `transactionId` question for the delivery contract, and Updated `09-29`. The freshness entry names it. No other row changed.
  - The disposition gained a freshness entry, and the `bookings` and `offline_conversions` rows' CR, findings and Next cells were updated.
  - The catalog's Google Ads registry row and §2b item 1 were updated.
  - The disposition and catalog are byte-identical to the reviewed prototype. The register differs from it only in the freshness entry and the PH8-9 row.
  - LF SHA-256: register `c47396d0679f7ba357cf509d1a0230646adbc274cafc1f8fc82abde606eda1d2`, disposition `241976811e54307d111282be93432e1dceb90bd43ee601be753cda702262d309`, catalog `03de48280159cd2b6d3b3c0195982a3496128ec7e79f600273679189ad0fca29`.

Per the DATABASE sequencing, these five paths stay uncommitted until Primary is deployed and the manifest remeasured.

### 2026-09-29 — Pre-deploy readiness gate

Run on HEAD `a266a5be92bab9ef5f4fae43b1028d6de704641b`, with the migration and Test 141 at their approved hashes.

- **Reset:** clean local reset to 238 migrations, latest `20260929120000`.
- **Focused test:** Test 141 27/27.
- **Out-of-file mutants:** base md5 of the two definitions and the trigger `27628da663ebacfbd5b29aea13bc5e6f`. Every installation was proven by a changed md5 and every restoration by the base md5.

  | Mutant | Failing assertions |
  | --- | --- |
  | M-A (RPC keeps its emission) | 2, 17, 18, 21 |
  | M-B (no override) | 7, 8, 9, 10, 20 |
  | M-C (state, not edge) | 17, 18, 21 |
  | M-D (no entry rule) | 15 |
  | M-E (no archived rule) | 12, 13, 14, 21 |
  | M-F (no risk flag) | 3, 5, 17, 18 |
  | M-G (reason leaks) | 4, 5, 11, 20, 27 |
  | M-H (override demanded without a session) | 19, 20, 21 |
  | M-I (balance judged on NEW) | 9, 10, 20 |

  No run aborted; each kill is an assertion.
- **In-file mutation:** with the trigger dropped in a savepoint, the door issue is silent and the mapper adds 0. Restored, it is recorded (assertions 25-27, inside the suite).
- **Unrepaired counterfactual:** the pre-repair objects were reinstated on the reset stack: the authority and trigger were dropped, and `app.advance_booking` was restored to its live pre-repair body, md5 `270170a9e13b1ff56b18eae592f206f8`, equal to Primary's. Test 141, without its in-file drop, fails assertions 4, 5, 8, 9, 10, 11, 13, 14, 15, 20 and 21, then aborts where the authority is absent. Restoration by re-applying the migration was md5-proven.
- **pgTAP Pass A:** 141 files / 2532 assertions PASS.
- **HTTP suites:** 33 + 40 + 74 + 122 + 120 + 60 = 449 passed, 0 failed. The declared `verify_lifecycle_branches.ps1` passed 122/122.
- **pgTAP Pass B,** without reset: 141 / 2532 PASS.
- **Smoke:** `ALL CHECKS PASSED`, exit 0.
- **Plan sum:** 141 files, 2532 assertions.
- **Local authority and trigger:**
  - `app.enforce_booking_lifecycle()` is SECURITY INVOKER, `search_path=""`, ACL `{postgres=X/postgres}`.
  - `bookings_enforce_lifecycle` is tgtype 21 (ROW, INSERT, UPDATE OF `booking_status_code`), AFTER, not a constraint trigger, and enabled.
  - `bookings` carries 10 non-internal triggers.
  - Definition md5: `app.advance_booking` `ec850eb7e8aa5c3233a59ef8697f2885`, `app.enforce_booking_lifecycle` `32153975bc13b0e392323ee4ad420273`.
- **Generators:** `MASTER_API_CONTRACT.md` changes one line as the Draft states: `advance_booking` no longer lists ALLOW_ISSUE_WITH_NEGATIVE_BALANCE and counts 4 raises instead of 5. It keeps 79 RPC endpoints, 8 views and 73 tables, and was restored until Step 7. `ai-map.json` differed only in `generated_at` and was restored.
- **Scope, diff check and consistency:**
  - The five changed paths are all in Write Scope, and `git diff --check` exited 0.
  - Repository consistency reports exactly the six expected pre-deploy issues: three migration-state drifts, two suite-figure drifts and the undeployed RECOVER-1 migration.

**Fresh Primary baseline,** read-only from `https://vrvtsxexkiiiivlkdxzp.supabase.co`:
- **Ledger:** 237 migrations, fingerprint `79a420205c451967b72ee0ccae917e0b`, equal to the recorded evidence. Latest `20260928180000`; the target is absent by version and by name.
- **Function surface:** `df53eb28ba5cbcffa45e1006d077ed61`/313.
- **Structural surface:** `_combined` `b372e1280a502d2c707713aca76a718e`/3069. Functions `df53eb28…`/313, triggers `cb10085173eb5a13ceefa6e951bb8fac`/302 and constraints `41023bb50efc61b2e139530345ff5908`/513; the other seven surfaces equal local's.
- **Pre-repair definition md5:** `app.advance_booking` `270170a9e13b1ff56b18eae592f206f8`.
- **Absent:** `app.enforce_booking_lifecycle` and `bookings_enforce_lifecycle`. `bookings` carries 9 non-internal triggers, and there is no default function ACL for schema `app`.
- **Business rows:** 0 tenants, bookings, per-user permission grants, invoices, events and offline conversions.

**Predicted delta,** equal to the local post-migration surface:
- **Ledger:** 238 migrations, latest `20260929120000`, fingerprint `8ac45c812287217f9c5ba25859e7348b`.
- **Functions:** `675e77e6d6f562b004d9eac7ac15505d`/314.
- **Triggers:** `6bdfd761a4c70e44ec3b74d58882a236`/303.
- **The other eight surfaces:** unchanged, constraints included, because this trigger owns no `pg_constraint` row.
- **Combined:** `ff2aeaf2e753134c44c3f721bfacdacf`/3071.
- **`bookings` triggers:** 10.
- **Definition md5:** `app.advance_booking` `ec850eb7e8aa5c3233a59ef8697f2885`, `app.enforce_booking_lifecycle` `32153975bc13b0e392323ee4ad420273`.
- **Business rows:** none written.

Stopped at Step 5: Human Gate 2.

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

- **EARN IT.** BOOK-10 was reproduced again at `2496591`, through to the missing `ticket_issued`, and three consequences it had not recorded were found: the archived-booking bypass, the booking born `issued` (ENTRY-1) and the session-less silence. Its trigger fired.
- **WORTH IT.** One function and one trigger on existing mechanisms, and one RPC body with rules removed, not added. No grant, policy, catalog row, other function or mapper changes. Without it, `ticket_issued` undercounts on a legal door and the override can be evaded by choosing the door.
- **SIMPLIFY IT WITHOUT WEAKENING.** Each issuance rule and each issuance event now has one owner instead of living in the RPC alone. The RPC holds only what a table write cannot carry. A new booking writer inherits every rule without knowing it exists. The trigger reads `OLD`, as the RPC did, which closes the one-statement customer rebinding the first prototype opened.
- **Future change cost.** One business fact, one authority per invariant, no provider concept in the booking layer, and behavioural tests pinned by mutants rather than SQL text. The RPC's transition table still duplicates `app.status_transitions`; that predates this contract and is left alone.
- **The API contract's dvance_booking row** now omits the override, because the generator reads each RPC body and the rule now lives in a table trigger; the contract's table-door section is where trigger-held rules are described. The generator is out of scope and unchanged.
- **Owner question, not a finding.** `reissue -> issued` yields a second `ticket_issued` today, as canon 26 and ADR-0020 treat it as issuance. Whether Google Ads should count a reissued ticket as a new Ticket Issued conversion is a delivery-contract question; this contract preserves the current behaviour.
- **Deliberately not changed:**
  - BOOK-11, the rest of BOOK-10's lifecycle rules on the door: recorded.
  - BOOK-12, the customer rebinding the RPC is also exposed to: recorded.
  - ARCH-2's `bookings` instance, a booking born archived: its own finding.
  - PH8-4, PH8-9 and the workflow: their own contracts, next.
  - The registered worktree `owt/p2` is untouched.
