# Change Request — SPEC-262

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Foundation Completion Programme Batch 6 Slice 39: give `public.complaints` a truthful disposition and close **COMP-2** and **COMP-3**.

The surface is canon 24's Complaint: a first-class customer complaint and its resolution workflow, linked to the customer and optionally to the booking or booking item it concerns. `authenticated` holds table-level INSERT, SELECT and UPDATE, and both RPCs, `app.create_complaint` and `app.advance_complaint`, are SECURITY INVOKER through that same grant, so PostgREST serves the table beside them.

After this change one invariant holds on both doors: **a complaint begins `new`, unresolved, unclosed, without a resolution note and unarchived, titled, owned and filed by whoever opens it, with exactly one `complaint_created` event at canon 27's `warning`; no signed-in UPDATE moves its owner or filing scope afterwards; every change of its status records exactly one canon-26 event; its resolution time, closure time and resolution note are the server's; and a closed complaint is reopened only with a reason.**

Record the surface `AUDITED` and close this surface's instances of **ENTRY-1** and **ARCH-2**.

This contract does not touch any permission charge, state transition, grant or policy, canon 24, 26, 27, 28 or 29, any other surface, n8n or any Phase-8 work.

## Business Reason

### Selection
`scripts/batch6_select_target.ps1`, recorded in SPEC-261's post-deploy certification entry at `88bc20a`, ranks `complaints` first among the 39 surfaces still `NOT-RECORDED`: Exposure 8, coverage 48. The runner-up is `payment_allocations` at 8/60. Fifteen pgTAP files mention complaints. They exercise the RPCs' happy path (17, 39, the care and journey HTTP suites), the trainee's refusal on both doors (67) and catalog sweeps; none attacks the table door's entry state, owner, events, times or resolution note.

### Authority
- **Canon 26 (Complaint State Machine):** the states are `new`, `acknowledged`, `in_progress`, `awaiting_customer`, `awaiting_supplier`, `resolved` and `closed`; the normal flow starts at `new`; `closed -> in_progress` is "reopened with reason by authorized user"; its required events are `complaint_created` and one for every transition (`_acknowledged`, `_in_progress`, `_awaiting_customer`, `_awaiting_supplier`, `_resolved`, `_closed`, `_reopened`). Its Transition Enforcement section states that the status trigger checks only validity and authority, not the RPCs' events, reasons or timestamps.
- **Canon 27:** every important business action creates an event that identifies its actor and time; **`complaint_created` is a warning**; `complaint_reopened` is a **warning** and requires a reopen reason; the other complaint events are info.
- **Canon 31:** `resolution_notes`, `resolved_at` and `closed_at` are nullable columns of the complaint; its timeline history is captured through immutable events.
- **The sole sanctioned writer, `app.create_complaint`** (`202607051500`): it charges CREATE_COMPLAINT, refuses a blank title, writes `new` and none of `resolved_at`, `closed_at` or `resolution_notes`, owns the complaint as the caller, files it under `app.current_placement()`'s branch and department (refusing a caller with no primary branch), and emits `complaint_created` — at `info`, where canon 27 says warning.
- **The sole sanctioned lifecycle writer, `app.advance_complaint`** (`202607057000`): it charges RESOLVE_COMPLAINT on every edge, stamps `resolved_at` with `now()` only on entering `resolved`, writes the reason given for resolving as `resolution_notes` only on that transition (COMP-1), stamps `closed_at` on entering `closed` and clears it on entering `in_progress`, takes none of the three from its caller, and records each transition's event with the caller's reason — all at `info`, including the reopen canon 27 makes a warning.
- **COMP-1** (FIXED, `202607057000`) made `resolution_notes` the complaint's record of how it was resolved.
- **SPEC-237** (`20260928160000`, CONV-8) gave a business act one AFTER-trigger producer for both doors, with its RPC handing the caller's reason through the transaction-local `app.transition_reason`, which the producer consumes.
- **SPEC-257** (`20261010120000`) closed exactly this shape on the sibling table `service_requests` (SR-1, SR-2), which carries the same grants, RLS shape, capability trigger and RPC pair.
- **Canon 29:** a Customer has many Complaints; a Complaint may optionally link to the Booking or Booking Item it concerns.
- **Archiving** is the UPDATE `app.enforce_archive_authority` charges ARCHIVE_RECORD for. No RPC creates a complaint archived.
- **ENTRY-1** (OPEN, engineering): the state machine governs every move except the first; `complaints` is one of four tables left, to be closed per surface. **ARCH-2** (OPEN, engineering): the archive guard never fires on INSERT; `complaints` is one of ten tables left, each to be proven in its own slice.

### COMP-2 (Medium) — a complaint created at the table door could be born closed, resolved or archived, owned by someone else, and leave no event
Measured at `88bc20a` on the local stack in one rolled-back transaction, by an `employee` placed in Main / Sales, proven first (`current_user`, `auth.uid()`) to hold CREATE_COMPLAINT and RESOLVE_COMPLAINT and not ARCHIVE_RECORD:
- **Born closed:** a direct INSERT created a complaint `closed`, with `resolved_at` 2020-01-01, `closed_at` 2020-01-02 and `resolution_notes` 'forged resolution'.
- **Born archived:** a direct INSERT created a complaint with `is_archived` true, `archived_by` a colleague and `archive_reason` 'forged narrative'.
- **Someone else's complaint:** a direct INSERT named a colleague in another branch as owner, and another was filed under that other branch and department. Both persisted, and that colleague then read both rows.
- **No event:** none of those rows emitted `complaint_created`. The same actor's RPC wrote `new`, owned and filed under itself, with one event, at `info`.
- **No branch:** test 154 shows an employee with no primary branch assignment creating a complaint directly, which the RPC refuses.
- **Two statements to the same exposure:** after a legitimate RPC creation, the same employee moved the owner to the colleague in another branch by a direct UPDATE, with no event. No RPC moves a complaint's owner or filing scope, and canon 28 defines no reassignment act or permission for one (CREATE, RESOLVE and VIEW_COMPLAINT only).
- **Blank title:** the table accepted a title of three spaces, and a later UPDATE blanked a title, which the RPC refuses.

A complaint is customer work, and canon 27 makes its opening a warning so it is seen. Its owner and branch decide who sees it and who answers for it; a complaint born closed or resolved never appears as open work and carries a resolution nobody gave; one born archived carries a narrative nobody was authorized to write.

### COMP-3 (Medium) — after creation, a complaint's life could be lived at the table door without its events, with forged resolution and closure times, a rewritten resolution note, and reopened without a reason on both doors
Measured at `88bc20a` by the same employee, who also holds RESOLVE_COMPLAINT:
- A legal direct UPDATE walked a complaint `new -> acknowledged -> in_progress -> resolved -> closed` with no transition event, `resolved_at` forged to 2001-01-01, `closed_at` forged to 2001-02-02 and `resolution_notes` forged at the resolve.
- A later UPDATE, with no status change, rewrote `resolved_at` to 2019-05-05 and `resolution_notes` to 'rewritten later': COMP-1's record of how the complaint was resolved was falsifiable after the fact.
- A direct UPDATE reopened `closed -> in_progress` with no reason and kept the stale `closed_at`, so an open complaint carried a closure time. `app.advance_complaint` reopened another with a null `p_reason`, and its `complaint_reopened` event was severity `info`.
- A session-less move left no event.

`app.status_transitions` refused none of it: it owns each edge and its permission, and canon 26 says so. The authority was already held, so nothing escalates; what was falsifiable was the record of what happened, when, and how it was resolved. Any of the six roles holding RESOLVE_COMPLAINT could do it, and the customer timeline lost the complaint's history. That is SR-2's and SUP-5's grade: Medium. The three columns each have one sanctioned writer, which stamps them from the server's clock and the resolving reason and accepts no other value; no canon rule gives them a business-effective date or free text. A historical import is a session-less platform write and keeps its latitude.

### The repair
One migration, in SPEC-257's shape:
- `app.guard_complaint_integrity()`, SECURITY INVOKER with an empty `search_path` and PUBLIC EXECUTE revoked, is attached as the row-level BEFORE INSERT OR UPDATE trigger `complaints_guard_integrity`.
  - For every caller it refuses a blank title (23514), as the RPC does.
  - On UPDATE, for a signed-in caller only:
    - it refuses a change to `owner_user_id`, `owner_branch_id` or `owner_department_id` (23514);
    - it refuses `closed -> in_progress` unless a non-blank `app.transition_reason` is present (23514);
    - on a change of status it sets `resolved_at` to `now()` on entering `resolved`, `resolution_notes` to the non-blank trimmed `app.transition_reason` (else the stored note) on entering `resolved`, and `closed_at` to `now()` on entering `closed` and to null on entering `in_progress`; otherwise it keeps all three stored values. This is exactly what `app.advance_complaint` writes.
  - Every other UPDATE passes through untouched, and session-less platform writes are exempt from the UPDATE arm.
  - On INSERT, for every caller it requires `new` with null `resolved_at`, `closed_at` and `resolution_notes`, and no archive field (23514).
  - For a signed-in caller it resolves `app.current_user_id()` and `app.current_placement()`, refuses with 42501 when there is no actor or branch, and derives `owner_user_id`, `owner_branch_id` and `owner_department_id`. Session-less platform writes keep their nullable owner.
- `app.emit_complaint_created()`, with the same security, is attached as the row-level AFTER INSERT trigger `complaints_emit_created`. It calls `app.record_event` with the RPC's exact event type, entity, state and payload keys (`customer_id`, `complaint_category_code`, `complaint_severity_code`), at canon 27's `warning`. The actor is the session's user, or null.
- `app.emit_complaint_transition()`, with the same security, is attached as the row-level AFTER UPDATE OF `complaint_status_code` trigger `complaints_emit_transition`, `WHEN` the status changes. It records canon 26's event for the state entered, `complaint_reopened` for `closed -> in_progress`, with the old and new states and the reason from `app.transition_reason`, which it consumes. The severity is `warning` for the reopen and `info` otherwise. The actor is the session's user, or null.
- `app.create_complaint` is replaced by its complete current definition, minus only its `app.record_event` call.
- `app.advance_complaint` is replaced by its complete current definition, with its `app.record_event` call replaced by `set_config('app.transition_reason', coalesce(p_reason, ''), true)` before its UPDATE, and the actor lookup that only that call used removed. Its transition map, permission charge and UPDATE statement are byte-identical.
- Both RPCs keep their signature, SECURITY INVOKER, `search_path` and `authenticated` EXECUTE.

No table, column, grant, policy, permission, event type, catalog value or state transition is added. Time is `now()`, the transaction's timestamp, which is what the RPC already uses.

### Rejected
- **Widening `complaints_enforce_archive_authority` to INSERT:** it would authorize and stamp an archive at creation, which no RPC does. Refusing at entry is what `documents` (SPEC-216) and `service_requests` (SPEC-257) chose for ARCH-2.
- **An entry-state row in `app.status_transitions`:** ENTRY-1 weighed and declined promotion repeatedly, because it changes INSERT behaviour on surfaces no slice has read; three tables remain after this one, each with its own creating RPC.
- **Revoking INSERT or UPDATE from `authenticated`:** both RPCs are SECURITY INVOKER and write through those grants; making them definers would move their RLS and capability semantics, a larger change than the defect.
- **Charging a permission for reassignment:** canon 28 defines none for complaints, and choosing one would be policy. Refusing the move is the fail-closed reading of the sole sanctioned writer, and canon 28's owner-ratified amendment 1 already lets a department colleague continue serving a customer when the assigned employee is absent, without reassignment.
- **Accepting a caller-supplied `resolution_notes` at a direct resolve:** the note COMP-1 created is the reason given for resolving, and the transition event carries the same reason; a second, free-text source would let the record and the event disagree. A direct PostgREST UPDATE cannot hand a reason, so a resolution with a note goes through `app.advance_complaint(..., p_reason)`, which already offers it.
- **Refusing a forged `resolved_at` or `closed_at` instead of stamping it:** a client echoing back the stored value, or moving without knowing the server's clock, would be refused. The server stamping its own time is what `app.enforce_archive_authority` and SPEC-257 do.
- **Keeping `complaint_created` at `info`:** canon 27 states warning, no consumer reads event severity (no trigger on `public.events` other than `events_append_only`, and no test or script pins the created event's severity), and the producer is written here anyway.
- **Making the transition trigger refuse every direct status change:** it would remove the legal, authorized table-door edges canon 26 Transition Enforcement keeps. Recording them is enough.
- **A transition-event mapping table (`values … as t(...)`) in the producer:** tests 07, 08 and 54 read such a block as a transition RPC. A `case` keyed by the state entered maps the same nine edges.
- **Deferring COMP-3 to a later slice:** the same table, guard, migration and test carry it, so a separate contract would cost a second approval, deployment and certification for a few lines.
- **An outbox, event bus or pgAudit:** `app.record_event` writes in the same transaction as the change, so a refused or rolled-back move leaves no event.
- **Clearing `resolved_at` or `resolution_notes` on reopen:** the sanctioned writer keeps both, and no canon rule says otherwise.

### Held, recorded so a later slice does not rediscover it
- **The UPDATE door's edges:** `app.status_transitions` charges RESOLVE_COMPLAINT on every status change. CREATE_COMPLAINT and RESOLVE_COMPLAINT are held by exactly the same roles (owner, ceo, branch_manager, department_manager, senior_employee, employee), so `guard_write_capability`'s either-permission rule on UPDATE escalates nobody.
- **Capability:** a trainee without CREATE_COMPLAINT is refused at the table (42501), measured.
- **Tenant:** a row under another tenant is refused by RLS. A foreign customer, booking, item, owner, branch or department is refused by the tenant-qualified foreign keys. There is no DELETE grant.
- **Customer–booking coherence:** `app.create_complaint` checks only that a booking or item is in the tenant, read from its code, so both doors accept a complaint under one customer naming another customer's booking in the same tenant. No canon rule states coherence, and no surface in the repository enforces it (`service_requests` recorded the same); recorded here and not invented.
- **Archive authority after creation:** an archive by the employee was refused `permission denied: ARCHIVE_RECORD`, measured; archiving, the archiver and the archive reason each still cost ARCHIVE_RECORD on UPDATE.
- **Department continuation:** canon 28's matrix reads Employee "Assigned only" for RESOLVE_COMPLAINT with scope `assigned/department`, and amendment 1 grants department visibility so a colleague can continue serving the customer. RLS enforces exactly that scope; it is not a defect.
- **TRANS-1** (the duplicated transition-permission source) is unchanged: `app.advance_complaint`'s transition map is byte-identical, and test 54 passes unchanged.

## Risks

- **Changed INSERT semantics.**
  - A signed-in direct INSERT now gets the creator's own owner and placement, whatever it supplies.
  - A non-`new`, resolved, closed, noted or archived entry is refused for every caller.
  - Nothing legitimate creates either today: the session-less writers are test 111's `new` fixture and none other; there is no seed; test 67's and the care suite's direct employee INSERTs name the employee's own placement and still succeed; both HTTP suites that create complaints otherwise use the RPC.
- **Signed-in reassignment stops.** A CREATE or RESOLVE holder can no longer move a complaint's owner or filing scope at the table. No RPC or HTTP suite does it, and no canon act defines it. The platform's session-less path keeps it.
- **The events move.** Each successful INSERT emits `complaint_created` once, from its trigger, now at `warning`; each change of status emits its transition event once, from its trigger. Neither RPC emits them itself. A refused INSERT or move emits nothing, and a no-op or field-only UPDATE emits nothing. Test 154 pins exactly one event per act on each door. The care suite's HTTP complaint, advanced nine times through the RPC, carried exactly one created event and nine transition events with their reasons and actor, the reopen at `warning`.
- **Changed UPDATE semantics.**
  - A signed-in `resolved_at`, `closed_at` and `resolution_notes` are the server's: stamped on the transition that owns them, kept otherwise, whatever the statement supplies.
  - A closed complaint is reopened only with a reason, on both doors; a direct PostgREST UPDATE cannot hand one, so a signed-in reopen goes through `app.advance_complaint(..., p_reason)`, which already offers it. Every HTTP RPC call already passes a reason.
  - A blank title is refused for every caller.
  - `complaint_reopened` and `complaint_created` are now severity `warning`, as canon 27 states.
- **The attribution inventory.** Test 83 assertion 23 pins the users-FK columns that no BEFORE trigger derives. The new guard derives `complaints.owner_user_id`, so exactly that member leaves the expected list. Its query, assertion 22 and every other member stay unchanged.
- **The transition and event parsers.** Tests 07, 08, 32 and 54 read app functions' text. The producer uses a `case`, not a `values … as t(...)` block, and every status the guard or producer compares with `=` is a registered destination. All four pass unchanged on the prototype.
- **Primary deployment** adds three functions and three triggers and replaces two function bodies, and nothing else. It requires separate exact-byte owner authorization (Gate 2); approving this contract does not authorize it.
- **Workstation, not in scope:** resets for this contract run from the main checkout.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-262-a-complaint-begins-new-under-its-creator.md`
- `supabase/migrations/20261011090000_a_complaint_begins_new_under_its_creator.sql`
- `supabase/tests/154_a_complaint_begins_new_under_its_creator_test.sql`
- `supabase/tests/83_actor_attribution_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607042400_create_crm_extension_tables.sql`
- `supabase/migrations/202607050900_customer_service_write_paths.sql`
- `supabase/migrations/202607051500_branch_filed_write_paths.sql`
- `supabase/migrations/202607052700_lifecycle_transition_enforcement.sql`
- `supabase/migrations/202607057000_capability_on_the_insert_path_and_a_message_that_cannot_be_forged.sql`
- `supabase/migrations/20261010120000_a_service_request_begins_requested_under_its_creator.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/17_employee_walkthrough_test.sql`
- `supabase/tests/21_read_scope_model_test.sql`
- `supabase/tests/32_lifecycle_transition_test.sql`
- `supabase/tests/54_transition_permission_parity_test.sql`
- `supabase/tests/58_write_grants_and_config_capability_test.sql`
- `supabase/tests/67_care_capability_and_message_integrity_test.sql`
- `supabase/tests/85_write_capability_on_update_test.sql`
- `supabase/tests/111_customer_surface_test.sql`
- `supabase/tests/149_a_service_request_begins_requested_under_its_creator_test.sql`
- `reports/architecture-decision-records.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/24_entity_registry.md`
- `_ORVION_CANONICAL/26_state_machines.md`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `_ORVION_CANONICAL/29_relationship_map.md`
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
- `_ORVION_CANONICAL/26_state_machines.md` (Complaint State Machine); `_ORVION_CANONICAL/27_event_catalog.md` (Complaint Events); `_ORVION_CANONICAL/28_permissions_matrix.md` (CRM permissions, read scope and amendment 1); `_ORVION_CANONICAL/29_relationship_map.md` (Customer To Complaint); `_ORVION_CANONICAL/31_schema_draft.md` (complaints)
- `reports/master/MASTER_GAP_REGISTER.md` (ENTRY-1, ARCH-2, COMP-1, SR-1, SR-2, TRANS-1); `reports/master/MASTER_SURFACE_DISPOSITION.md`; `reports/master/MASTER_EXECUTION_PLAN.md` Batch 6 method and EC-1…EC-11
- `supabase/migrations/202607051500_branch_filed_write_paths.sql`; `supabase/migrations/202607057000_capability_on_the_insert_path_and_a_message_that_cannot_be_forged.sql`; `supabase/migrations/20260928160000_a_qualified_lead_and_a_booking_are_recorded_on_every_door.sql`; `supabase/migrations/20261010120000_a_service_request_begins_requested_under_its_creator.sql`
- Current local `app.create_complaint`, `app.advance_complaint`, `app.record_event`, `app.current_placement`, `app.guard_write_capability`, `app.enforce_status_transition`, `app.enforce_archive_authority`
- Tests 07, 08, 17, 32, 54, 67, 83 (assertion 23), 111 and 149

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

- `pwsh -NoProfile -File scripts/verify_care_journeys.ps1`
- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A signed-in INSERT is `new`, unresolved, unclosed, un-noted, unarchived and titled, owned and filed by its creator | `scope_isolation` RLS; `app.advance_complaint`; `app.status_transitions`; `app.enforce_archive_authority` | WRITE | The prototype was the migration applied, with its ledger row, to the certified `88bc20a` local stack (249 migrations); the files were held outside the repository. Migration SHA-256 `55d54a8a26265f6ea7aaee3708906ca4c25d9ae79cbe4ab831ff17278adecb02`, md5 `43ed834051349c20b746b721236b639a`, 15136 bytes, 311 LF lines, ASCII. A forged owner and a forged filing scope were replaced by the creator's own; the colleague in the other branch then saw 0 rows. Closed, resolved, closure-timed, noted, archived, archiver-named and blank-titled entries were refused 23514. An employee with no primary branch was refused 42501. |
| A signed-in UPDATE keeps the owner, filing scope and title, takes the server's `resolved_at`, `closed_at` and resolution note, and reopens only with a reason | `app.advance_complaint`; `app.status_transitions`; `app.enforce_archive_authority`; `guard_write_capability` | WRITE | After creation, a signed-in move of the owner or filing scope, a blanked title, and a reopen with no reason (direct, or through the RPC with a null `p_reason`) were each refused 23514, while an ordinary edit succeeded. `resolved_at`, `closed_at` and the resolution note forged at the move, and `resolved_at` and the note rewritten afterwards, each gave way to the server's values; a direct resolve without a reason leaves the note null. The RPC's resolve recorded its reason as the note (COMP-1), and its reopen with a reason cleared `closed_at` and kept the resolution. Every edge, its permission and the archive charge are unchanged: tests 32 (11/11) and 54 (6/6) pass unchanged. |
| The created and transition events move from the RPC bodies to AFTER producers; `complaint_created` becomes `warning` | `public.events`; `app.customer_timeline`; tests 17 and 67; `verify_care_journeys.ps1` and `verify_journey_branches.ps1` | WRITE | Before: a direct creation or move emitted 0 events, and each RPC act emitted 1, all `info`. Prototype: each direct and RPC creation emitted exactly 1 at `warning`, with the RPC's payload and the creator as actor, and reached the customer timeline. Each direct and RPC move emitted exactly 1, with its states, its reason and its actor; the reopen was a `warning`. A refused act, a no-op status UPDATE and a field-only UPDATE emitted none, and a reason handed to one transition opened no other. Both HTTP suites pass unchanged (care 40/0, journey 85/0). Afterwards the care suite's complaint carried one created event at `warning` and exactly nine transition events, each with the reason the suite passed and the employee as actor, the reopen at `warning`; its resolution note equalled the resolving reason and its `closed_at` was null after the reopen. Tests 17 (18/18) and 67 (25/25) pass unchanged. No trigger, test or script reads event severity. |
| The event and status vocabulary guards | tests 07, 08, 32, 54 (they read app functions' text) | VERIFY | The producer maps states with a `case`, not a `values … as t(...)` block, and every status it or the guard compares with `=` (`new`, `closed`, `in_progress`, `resolved`) is a registered destination or the entry state. `app.advance_complaint`'s transition map is byte-identical. On the prototype: 07 2/2, 08 2/2, 32 11/11, 54 6/6. |
| Session-less INSERT and UPDATE | test 111's fixture; future platform writers, including a historical import | VERIFY | The entry state binds a session-less write too (a session-less `closed` creation is refused 23514), and the title rule precedes the guard's session test. A session-less `new` creation keeps its null owner and emits once with a null actor. Session-less moves emit once each with a null actor and keep the `resolved_at` they carry. Test 111 passes unchanged (57/57). |
| Creation ownership becomes trigger-derived and fixed against signed-in UPDATEs | `83_actor_attribution_test.sql` assertion 23 | WRITE | Its query lists users-FK columns that `authenticated` can write and no BEFORE trigger derives. The guard removes `complaints.owner_user_id` from that measured set, and on the prototype only assertion 23 failed until exactly that member was removed. Test 83: SHA-256 `16235efe12063c32dcfe0107c8f6423f4349df8f6d3eed246e7f6b90dd2f4a34`, 21170 bytes → `2aa3576c4e203e67e0c1d13ed3eee592b5cda419744496c19b33747dde96cb82`, 21144 bytes, a one-line diff deleting `complaints.owner_user_id, `. Then 23/23. |
| Test 154 | `supabase/tests` | WRITE | SHA-256 `7045e732a563ea39b2398a260cbc33a1832ce7200e36a3fc1d73ac392395dfe8`, `plan(53)`, 24728 bytes, 296 LF lines, ASCII: 53/53 on the prototype. On the unrepaired `88bc20a` schema 35 fail, each for its intended reason: 5, 6, 7, 8, 9, 11, 12, 13, 15, 16, 17, 18, 19, 20, 22, 26, 27, 30, 32, 33, 34, 35, 36, 37, 38, 39, 41, 42, 44, 46, 48, 49, 50, 52, 53. |
| Other tests reading this table or its functions | tests 10, 21, 39, 53, 58, 79, 85, 88 | VERIFY | Each passes unchanged on the prototype: 9/9, 25/25, 16/16, 12/12, 27/27, 19/19, 16/16, 25/25. |
| The generated API contract | `MASTER_API_CONTRACT.md` | WRITE | The canonical generator against the prototype reports 80 RPC endpoints (80 with HTTP evidence), 8 views and 74 tables. It is byte-identical to the committed contract (SHA-256 `d28fb5672ca9c0795a99a74746069c973e1392edcc5e3d2a5a315348138175fd`): no grant, table or client RPC moves. Step 7 regenerates it, and it stays unchanged. |
| Suite and smoke | full pgTAP; `scripts/verify_database.sql` | VERIFY | On the prototype every one of the 154 files (the 152 unchanged committed files, test 83 as edited and test 154) passed its full plan, 2868 assertions (2815 + 53), 0 failed; the plan sum is 154 / 2868. Smoke: `ALL CHECKS PASSED (78 tables, … 71/622 catalog, …)`. The four HTTP suites that do not name complaints (`verify_api_end_to_end`, `verify_lifecycle_branches`, `verify_role_journeys`, `verify_storage_end_to_end`) call neither RPC and write no complaint, and are not declared. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | The certified `88bc20a` local stack equalled the recorded Primary values (249 migrations, `323eae75c4a400b4cc6f13317ec21611`; functions `724baac791a6a79c7d4328835d800f50`/323; triggers `a46035c1b6ce74d5d87fa46a40571e16`/309; combined `5a9ed7ff90852acec9a128b7fe4f8c5a`/3115). With the migration, functions became `3d7eb4e3550f7cec15815defb600272d`/326, triggers `61f9789b320a4eb988542b83beee36ca`/312 and combined `a23669c9c5c31f56bed4f7e8d265c534`/3121. Policies `b67d466a…`/125, constraints `cea733ef…`/525, grants `6727f6d8…`/189, columns `448db887…`/1134, views `10bb212a…`/16, indexes `22a4d58c…`/300, status transitions `db2165c7…`/115 and RLS `c117cbf7…`/79 each equal the recorded Primary value. The 250-row ledger fingerprint is `24b8778b6d9e955a8472affb07712858`. |
| Measured state that moves | manifest (`Live state`, suite figure, coverage, Last Completed, Current Module, Next capability); `primary-ledger-evidence.json`; `ai-map.json` | WRITE | 249 → 250 migrations, latest `20261011090000`; 153 → 154 files and 2815 → 2868 assertions; coverage 39 → 40 of 78. HTTP (464), tables (78), catalog (71/622), views (8) and client RPCs (80) do not move. Primary values are written only from fresh post-deploy readings. |
| COMP-2 and COMP-3 fixed, ENTRY-1 and ARCH-2 annotated; the surface `AUDITED` | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24, 25 | WRITE | Test 154's `-- ATTACK-CLASSES:` line and negative assertions satisfy Check 24 for `complaints`. COMP-2's and COMP-3's Owner field is `—`, so Check 25 reads no owner decision. The disposition row names this contract as its session, and the coverage line becomes 17 `AUDITED`, 20 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT` and 38 `NOT-RECORDED`. Step 4 runs Checks 21 to 25 on the applied edits. |
| CI-only guard self-tests and repository consistency | `scripts/test_*_guard.ps1` (four); `scripts/check_repository_consistency.ps1` | VERIFY | Predicted from SPEC-257's and SPEC-261's identical shape, and measured at Step 4: before deployment, repository consistency reports exactly the measured-state drift — `manifest says 249 migrations, repository holds 250`; latest `20261010210000` vs `20261011090000`; ledger fingerprint `323eae75…` vs `24b8778b…`; `153 test files` vs 154; `2815 assertions` vs 2868; RECOVER-1 ledger evidence — and the primary-ledger and cold-start self-tests fail only their CONTROL and restore cases because of it. These are not waived: Step 7 makes them true, and Step 8 requires them green. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused tests, pgTAP A/B, the declared HTTP suites, smoke and mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| COMP-2, COMP-3, ENTRY-1, ARCH-2 and the disposition describe the local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |
| The four CI-only guard self-tests pass | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: `app.enforce_status_transition` fires on UPDATE only and judges each edge and its permission, not its event, reason or time (canon 26 Transition Enforcement). `app.enforce_archive_authority` fires on UPDATE only. `app.guard_write_capability` charges CREATE_COMPLAINT (or RESOLVE_COMPLAINT on UPDATE) but checks no entry state, creator, owner move, title, time, resolution note, reason or event. RLS judges scope against caller-supplied owner fields, so a creator's WITH CHECK passes for a move it makes itself. Only the RPCs supply the correct values and events. This contract reuses `app.record_event`, `app.current_placement()`, `app.current_user_id()`, the capability trigger, the status trigger, the existing RLS and foreign keys, and SPEC-237's `app.transition_reason` hand-off, in SPEC-257's exact shape. No shared entry, lifecycle or event framework is earned (ENTRY-1 declined promotion each time).

Added Property: A successful INSERT through either door begins `new`, unresolved, unclosed, without a resolution note, unarchived and titled, under the actual creator and placement for a signed-in caller, and emits exactly one `complaint_created` at `warning` with the RPC's payload. Afterwards no signed-in UPDATE moves the owner or filing scope or blanks the title. Every change of status through either door emits exactly one canon-26 event with its states, reason and actor, and the reopen is a `warning`. A signed-in caller's `resolved_at`, `closed_at` and `resolution_notes` are the server's. A closed complaint is reopened only with a reason. A refused act emits nothing.

Causal Negative: These are the pre-repair measurements in Business Reason, at `88bc20a`:
- direct creation `closed` with forged `resolved_at`, `closed_at` and `resolution_notes`;
- direct creation archived with a colleague as `archived_by` and a forged reason;
- direct creation naming a colleague in another branch as owner, or filed under that branch, readable by that colleague;
- zero `complaint_created` events for every direct creation, and the RPC's at `info`;
- after a legitimate creation, a direct UPDATE moving the owner to the colleague in another branch;
- a blank title at creation and a blanked title afterwards;
- a direct walk to `closed` with no transition event and forged times and note, then `resolved_at` and the note rewritten alone;
- a reopen with no reason, through the table (keeping a stale `closed_at`) and through the RPC, the RPC's event at severity `info`;
- a session-less move with no event.

On the unrepaired schema, test 154 fails assertions 5, 6, 7, 8, 9, 11, 12, 13, 15, 16, 17, 18, 19, 20, 22, 26, 27, 30, 32, 33, 34, 35, 36, 37, 38, 39, 41, 42, 44, 46, 48, 49, 50, 52 and 53, each for its intended reason. The causes are:
- the forged owner or filing kept, at creation or by a later UPDATE;
- no event at creation or on a move, or the created event at `info`;
- the forged times or note kept, or the note rewritten afterwards;
- no exception where 23514 or 42501 was required;
- the reopen recorded as `info`;
- the colleague seeing 2 rows;
- the triggers and functions absent.

Positive Test Design: The tenant has two branches, each with a sales department. The employee and the trainee are placed in Main / Sales and the colleague in Other / Other Sales; a fourth employee has no branch assignment; there is one customer and a rival tenant. Positive controls:
- the employee's direct creations persist under the employee and Main / Sales despite a forged owner or filing scope;
- each direct and RPC creation emits exactly one `warning` event with the RPC's payload and reaches the customer timeline;
- `app.advance_complaint` still advances and emits once with its reason, and an ordinary edit of the complaint still succeeds;
- a direct walk `new -> acknowledged -> in_progress -> resolved -> closed` succeeds and records exactly four events, as the employee; a no-op status UPDATE and a field-only UPDATE record none;
- the RPC resolves with its reason recorded as the resolution note and both times stamped, closes, and reopens with a reason, recording exactly one event per move, the reopen a `warning` carrying its reason; the reopened complaint has no closure time and keeps its resolution;
- a session-less `new` creation keeps its null owner and emits once with a null actor; session-less moves emit once each with a null actor and keep the `resolved_at` they carry.

Negative Test Design:
- **Entry state:** `closed` entry, and `new` with a resolution time, a closure time or a resolution note, are refused 23514, signed in; a session-less `closed` entry is refused too.
- **Archive:** archived entry, and an archiver-named entry, are refused 23514.
- **Placement:** an employee with no primary branch is refused 42501.
- **Owner after creation:** the creator's direct UPDATE moving the owner to a colleague in another branch, or the filing scope to another branch, is refused 23514.
- **Times and note:** `resolved_at`, `closed_at` and the note forged at the move, and `resolved_at` and the note rewritten afterwards, are replaced or kept by the server; a signed-in rewrite of an RPC-recorded note does not stand.
- **Reopen:** a direct reopen with no reason, and the RPC's with a null reason, are refused 23514; after a reasoned RPC reopen, the same direct reopen is still refused.
- **Title:** a blank title at creation and a blanked title afterwards are refused 23514.
- **Capability:** a trainee without CREATE_COMPLAINT is refused 42501.
- **Tenant:** a row under another tenant is refused 42501 by RLS.
- **Visibility:** the colleague named as owner, and the branch named as filing scope, see 0 rows.
- **Events:** refused creations add no event; a refused reopen adds none.

Non-Empty Population Obligation: One tenant with two branches and two departments, four placed or unplaced users with their roles, one customer, and a rival tenant. Every creation, move and denial is counted by row or event id; no zero-row operation satisfies an assertion.

Mutation Obligation: Out of file, record a surface: the md5 of the guard's, both producers', and both RPCs' definitions, with the table's trigger definitions. For each mutant:
1. Install it inside test 154's own transaction and prove the surface differs.
2. Run test 154 and record the failing assertions.
3. Prove after the rollback that the surface equals the base.

A mutant whose installation is not proven is a harness error, never a kill.

| Mutant | Change | Expected to fail |
| --- | --- | --- |
| M1 | the entry-state arm removed | 15, 16, 17, 18, 22, 30 |
| M2 | the `resolved_at` entry conjunct removed | 16, 22 |
| M3 | the `closed_at` entry conjunct removed | 17, 22 |
| M4 | the `resolution_notes` entry conjunct removed | 18, 22 |
| M5 | the archive arm removed | 19, 20, 22 |
| M6 | the archive arm reads only `is_archived` | 20, 22 |
| M7 | the owner derivation removed | 5, 6, 26 |
| M8 | the placement requirement removed | 27 |
| M9 | the created producer dropped | 7, 8, 9, 11, 22, 32, 34 |
| M10 | `app.create_complaint` keeps its own event call | 22 |
| M11 | the UPDATE owner arm removed | 12, 13 |
| M12 | the UPDATE arm checks only `owner_user_id` | 13 |
| M13 | the transition producer dropped | 24, 37, 38, 39, 44, 46, 47, 50, 52 |
| M14 | `app.advance_complaint` keeps its own event call | 24, 47 |
| M15 | the producer does not consume the reason | 38, 39, 46 |
| M16 | the reopen-reason arm removed | 39, 42, 46 |
| M17 | the `resolved_at` stamp removed | 38 |
| M18 | the `closed_at` stamp removed | 38 |
| M19 | the resolution note passes through | 38, 41 |
| M20 | the session-less exemption removed from the UPDATE arm | 51 |
| M21 | the reopen recorded as `info` | 44 |
| M22 | the title arm removed | 48, 49 |
| M23 | the producer fires on a no-op status UPDATE | 37 |
| M24 | `app.advance_complaint` hands no reason | 24, 40, 41, 43, 44, 45, 47 |
| M25 | the created event recorded as `info` | 8, 11 |
| M26 | the reopen's `closed_at` clear removed | 45 |

M13 and M15 also fail 38: the reason handed by assertion 23's RPC call is then never consumed, and the later direct resolve takes it as the resolution note.

Prototype result: base surface `10856b75f76cb92cf25e71c819e730e0`. Every installation changed the surface, and every rollback returned it to the base. All twenty-six were killed, exactly as listed.

Post-Implementation Proof Obligation: All of the following, on the final bytes and through canonical `-Finish`:
- the focused test, a clean reset from the main checkout, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke;
- the out-of-file mutations M1–M26 and the pre-repair causal negative;
- the generated artifacts, the four CI-only guard self-tests, repository consistency and `git diff --check`;
- fresh Primary evidence, parity evidence and the Primary ledger check.

## Implementation Steps

1. **Check** that `supabase/migrations/20261011090000_a_complaint_begins_new_under_its_creator.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `55d54a8a26265f6ea7aaee3708906ca4c25d9ae79cbe4ab831ff17278adecb02`, md5 `43ed834051349c20b746b721236b639a`, 15136 bytes.
   - Its statements create, each with PUBLIC EXECUTE revoked:
     - `app.guard_complaint_integrity()` with its BEFORE INSERT OR UPDATE trigger;
     - `app.emit_complaint_created()` with its AFTER INSERT trigger;
     - `app.emit_complaint_transition()` with its AFTER UPDATE OF `complaint_status_code` trigger, `WHEN` the status changes.
   - They then replace `app.create_complaint(...)` without its event call, and `app.advance_complaint(...)` with the reason hand-off in place of its event call. A comment block precedes them, stating the authority and COMP-2's and COMP-3's measurements.
   - If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/154_a_complaint_begins_new_under_its_creator_test.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `7045e732a563ea39b2398a260cbc33a1832ce7200e36a3fc1d73ac392395dfe8`, `select plan(53);`.
   - Its `-- ATTACK-CLASSES:` line reads `AUTH TENANT DOOR STATE OBSERVABILITY PRIVILEGE INPUT BUSINESS=N/A CONCURRENCY=N/A REPLAY=N/A`, with each `N/A` reason in its header.
   - Then, in `supabase/tests/83_actor_attribution_test.sql`, delete only `complaints.owner_user_id, ` from assertion 23's expected list, giving SHA-256 `2aa3576c4e203e67e0c1d13ed3eee592b5cda419744496c19b33747dde96cb82`.
   - If a target carries content other than its `88bc20a` bytes or its frozen value, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` already contains a `COMP-2` row. If not, make these edits and nothing else:
   - **Register:**
     - a 2026-10-11 Slice-39 freshness entry, with the previous one demoted to `Previously:`;
     - after SR-2, a new row COMP-2 (Medium), FIXED by SPEC-262 locally with Primary pending and Cert `🛡`, with the measurements above;
     - a new row COMP-3 (Medium), FIXED by SPEC-262 locally with Primary pending and Cert `🛡`, with the measurements above;
     - both rows with Owner `—` and this contract as session;
     - ENTRY-1 gains a dated SPEC-262 entry: `complaints` closed, the ninth instance, three tables remain, no generic entry rule; its last date becomes 10-11;
     - ARCH-2 gains a dated SPEC-262 entry: `complaints` refused at entry for every caller, the count falls to nine; its last date becomes 10-11.
   - **Disposition:**
     - a freshness entry, with the previous one demoted;
     - coverage 40 of 78 (17 `AUDITED`, 20 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 38 `NOT-RECORDED`) and the "All 40" line;
     - the `complaints` row `AUDITED` / `ADVERSARIAL` / SPEC-262 / COMP-2, COMP-3, ENTRY-1, ARCH-2, with its evidence and its swept non-defects.

   If a target carries content other than its `88bc20a` bytes, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 values:
   - a clean local reset from the main checkout; test 154 and the focused tests 07, 08, 17, 32, 54, 67, 83, 111 and 149;
   - pgTAP Pass A, both declared HTTP suites, then pgTAP Pass B without reset; smoke and the plan sum;
   - the mutation evidence M1–M26, and the causal negative;
   - the API-contract and map generators;
   - the four CI-only guard self-tests;
   - the scope check, `git diff --check` and repository consistency.

   Treat as expected at this boundary only:
   - an undeployed Primary;
   - the pre-deploy repository-consistency drift listed in Consumer Closure;
   - the guard self-test CONTROL failures that drift causes.

   Read a fresh Primary baseline, read-only:
   - the project URL, the full ordered ledger and the absence of the target migration;
   - the function and structural surfaces;
   - `complaints`' triggers; `app.create_complaint`'s and `app.advance_complaint`'s text md5, security mode and ACL;
   - the tenant, complaint and event counts.

   Record the predicted delta.
5. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 4 and present the Gate-2 package. Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261011090000_a_complaint_begins_new_under_its_creator`. If it is absent and deployment is separately authorized:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts, the table's triggers and both RPCs' md5.
   - On an exact match, prove the transmitted text's md5 server-side, then apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires:
     - exactly one new row;
     - its stored statement md5 equal to the file's;
     - no existing target version.
   - Read fresh:
     - the ledger, the function surface and all ten structural surfaces;
     - the table's triggers;
     - the five functions' definitions, security modes and ACLs;
     - the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with 464 HTTP assertions unchanged.
   - Confirm that `supabase/tests` holds 154 files whose literal `plan(N)` values sum to 2868, then set `Suite **154 files / 2868 assertions**`. If either differs, stop.
   - Set Batch 6 coverage to 40 of 78, all forty at `ADVERSARIAL`.
   - Mark COMP-2 and COMP-3 `DEPLOYED` with Cert `✅`, worded without a date beneath the register's freshness line.
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
     - set `Last Completed` to SPEC-262 / Slice 39;
     - set `Current Module` to Foundation Completion Programme Batch 6 resuming at Slice 40;
     - set `Next capability` to **Foundation Completion Programme — Batch 6 Slice 40**, naming the measured first target, followed by the existing Phase-8 order, closed-chapter and standing-fact sentences unchanged;
     - keep the manifest within 7000 characters;
     - regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate with `scripts/publish_candidate.ps1` and require exact-SHA candidate CI.
   - Promote the same accepted SHA, require main CI, and run `-Certify` for `REMOTE_CERTIFY: READY`.
   - Verify synchronized clean refs.

## Acceptance Criteria

- [x] A direct INSERT by a signed-in CREATE_COMPLAINT holder persists the complaint under the creator and the creator's placement, whatever owner or filing scope it supplies; the colleague it named sees 0 rows; an employee with no primary branch is refused 42501.
- [x] After creation, a signed-in UPDATE cannot move the complaint's owner or filing scope or blank its title (23514), while an ordinary edit succeeds.
- [x] A complaint cannot be created other than `new`, with a resolution time, a closure time, a resolution note, archived, naming an archiver or with a blank title (23514); the entry state binds session-less creation too.
- [x] Each successful direct and RPC creation emits exactly one `complaint_created` event at `warning`, with the RPC's state and payload and the creator (or null) as actor, and reaches the customer timeline; a refused creation emits none.
- [x] Each change of status, direct or through `app.advance_complaint`, emits exactly one canon-26 event with its old and new states, its reason and the session's actor (or null). The reopen is `complaint_reopened` at `warning`. A no-op status UPDATE, a field-only UPDATE and a refused move emit none.
- [x] A signed-in caller's `resolved_at`, `closed_at` and `resolution_notes` are the server's: stamped on the transition that owns them and otherwise kept, whatever the statement supplies; the RPC's resolving reason is the resolution note; a session-less write keeps the values it carries.
- [x] A closed complaint cannot be reopened without a reason, directly or through the RPC (23514); the RPC reopens with one, clearing `closed_at`; a reason is consumed by the transition it was handed to.
- [x] `app.create_complaint` differs from `88bc20a`'s only by the removed event call. `app.advance_complaint` differs only by its event call and the actor lookup that call used being replaced by the reason hand-off; its transition map, permission charge and UPDATE are byte-identical. Both keep their signature, security mode, `search_path` and ACL.
- [x] The held controls stay held: a trainee is refused at the table; a row under another tenant is refused by RLS; session-less `new` creation keeps its null owner; every edge and its permission are unchanged.
- [x] Mutants M1–M26 are each killed against test 154, with installation and restoration proven. The causal negative is recorded.
- [x] Test 83 assertion 23's expected list drops only `complaints.owner_user_id`; its query, assertion 22 and every other member are unchanged.
- [x] COMP-2 and COMP-3 are fixed and deployed in the register. ENTRY-1 and ARCH-2 each record this surface's closure; COMP-1, SR-1 and SR-2 are unchanged.
- [x] `complaints` is `AUDITED` / `ADVERSARIAL` in the disposition record, and coverage is 40 of 78. No other surface's row changed.
- [x] The migration, test 154 and test 83 matched their frozen SHA-256 values when applied.
- [x] Primary, the recorded evidence, the manifest (250 migrations; 154 files / 2868 assertions; 464 HTTP assertions), the API contract and `ai-map.json` agree, and the four CI-only guard self-tests and repository consistency pass.
- [x] The manifest names Batch 6 Slice 40 and its measured target as the next capability, with no Active Change Request.
- [x] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [x] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-10-11 — Gate 1 approval and execution started

- **Authority:** the owner's SPEC-262 exact-identity approval (2026-10-11). It approves Gate 1 for Draft `122fd657647916720f6b21f002c20f03f752b0dd`, contract SHA-256 `f3e4dedc5d4f64a930729170545db9285b59269b2025c7487f2b9e810e9e04a9`, to close COMP-2 and COMP-3 with this surface's ENTRY-1 and ARCH-2 instances. Verified before acting:
  - HEAD was the Draft commit, 1 ahead of and 0 behind `origin/main` `88bc20a`, and the working tree was clean;
  - the contract file and its committed blob both hash to the approved value;
  - the frozen prototype files in the scratchpad `p262` hash to their Step 1–2 values: migration `55d54a8a…` (MD5 `43ed8340…`, 15136 bytes, 311 LF, 0 CR), test 154 `7045e732…` (24728 bytes), test 83 `2aa3576c…` (21144 bytes); the committed test 83 is its `88bc20a` bytes `16235efe…`;
  - Write Scope is the ten paths above.

  Approval was committed at `2ca3f10`; its pre-commit Gate returned `APPROVAL_EVIDENCE: PASS`.
- **Preconditions:** the migration and test 154 are absent. Test 83, the register, the disposition record, the API contract, the Primary evidence file and the manifest's measured state are unchanged since `88bc20a`.
- **Publication range:** before this commit, `origin/main..HEAD` held 2 commits with 0 merges and was 0 behind.
- **Worktrees.** A read-only inventory; nothing was modified.
  - `wt251` is clean at `578f3fb`, and `owt/p2` is clean at `7fe62ed`.
  - `wt255` at `33e4db6` has 6 entries, `wt260` at `e26733a` has 4, `wt261` at `39ab45a` has 6, and `C:\w234` at `6c48fbb` has 15.

  All stay untouched.
- **Gate 2 stands before Step 6.** The same approval grants a separate, advance, one-time, exact-byte Gate 2 for migration SHA-256 `55d54a8a26265f6ea7aaee3708906ca4c25d9ae79cbe4ab831ff17278adecb02` (MD5 `43ed834051349c20b746b721236b639a`, 15136 bytes, LF) to Primary `vrvtsxexkiiiivlkdxzp` only. It takes effect only after Step 4's readiness requirements pass, and it is recorded at Step 5 only if they do. Secondary is never contacted.

### 2026-10-11 — Steps 1–3 applied; pre-deploy readiness gate

- **Steps 1–2.** The three files were copied byte for byte from the scratchpad `p262` and hash to their frozen values:
  - migration `supabase/migrations/20261011090000_a_complaint_begins_new_under_its_creator.sql`: SHA-256 `55d54a8a26265f6ea7aaee3708906ca4c25d9ae79cbe4ab831ff17278adecb02`, MD5 `43ed834051349c20b746b721236b639a`, 15136 bytes, 311 LF, 0 CR;
  - test 154: `7045e732a563ea39b2398a260cbc33a1832ce7200e36a3fc1d73ac392395dfe8`, 24728 bytes, `plan(53)`;
  - test 83: `16235efe…` → `2aa3576c4e203e67e0c1d13ed3eee592b5cda419744496c19b33747dde96cb82`, 21144 bytes, a one-line diff deleting `complaints.owner_user_id, `.
- **Step 3.** The register now holds COMP-2 and COMP-3 after SR-2, each FIXED locally with Primary pending and Cert `🛡`, Owner `—`, with a 2026-10-11 freshness entry. ENTRY-1 gains its SPEC-262 entry (ninth instance, three tables remain) and ARCH-2 its own (the count falls to nine); both now end `10-11`. The disposition record carries a freshness entry, coverage `40 of 78 recorded · 17 AUDITED · 20 AUDITED-OPEN · 3 PARTIAL · 0 EXEMPT · 38 NOT-RECORDED`, "All 40", and the `complaints` row `AUDITED` / `ADVERSARIAL`. Register SHA-256 `e8ad4552101eb2d5a5ccf9023a1cab0429562521a8ac2c3b6e5d34c519b91267`, disposition record `494a94cac60ee2ce675334f394f03a9e88cb9fa82c228b074596555ba993f39b`.
- **Causal negative, first, on the still-unrepaired 249 stack:** the committed test 154 passed 18 and failed 35, exactly 5, 6, 7, 8, 9, 11, 12, 13, 15, 16, 17, 18, 19, 20, 22, 26, 27, 30, 32, 33, 34, 35, 36, 37, 38, 39, 41, 42, 44, 46, 48, 49, 50, 52, 53.
- **Clean reset** (`npx supabase db reset`, main checkout): 250 migrations, latest `20261011090000`, ledger `24b8778b6d9e955a8472affb07712858`; `complaints` carries 10 triggers. `scripts/parity_surface.sql` reads functions `3d7eb4e3550f7cec15815defb600272d`/326, triggers `61f9789b320a4eb988542b83beee36ca`/312, combined `a23669c9c5c31f56bed4f7e8d265c534`/3121, and the other eight surfaces at their recorded Primary values — each equal to the Pre-Approval prediction.
- **Focused tests:** 154 53/53, 07 2/2, 08 2/2, 17 18/18, 32 11/11, 54 6/6, 67 25/25, 83 23/23, 111 57/57, 149 48/48.
- **Mutation M1–M26:** base surface `10856b75f76cb92cf25e71c819e730e0`. Every installation changed it, every rollback restored it, and all twenty-six were killed with exactly the frozen failing assertions.
- **In `-Finish`'s order:** pgTAP Pass A `Files=154, Tests=2868, Result: PASS`; `verify_care_journeys.ps1` 40 passed, 0 failed; `verify_journey_branches.ps1` 85 passed, 0 failed; pgTAP Pass B without reset `Files=154, Tests=2868, Result: PASS`; smoke `ALL CHECKS PASSED (78 tables, … 71/622 catalog, …)`. Plan sum 154 files / 2868.
- **Generators:** the API contract regenerates byte-identical (`d28fb5672ca9c0795a99a74746069c973e1392edcc5e3d2a5a315348138175fd`; 80 RPC endpoints, 8 views, 74 tables). The map is regenerated at Step 7.
- **CI-only guard self-tests:** future-date 18/0 and status-contradiction 33/0 pass. Cold-start (25 passed, 9 failed) and primary-ledger (11 passed, 2 failed) fail only their CONTROL and restore cases, which require an untouched copy to be CLEAN; every mutation case passes.
- **Repository consistency:** exactly the predicted drift, 6 issues — 249 vs 250 migrations; latest `20261010210000` vs `20261011090000`; ledger `323eae75…` vs `24b8778b…`; 153 vs 154 test files; 2815 vs 2868 assertions; RECOVER-1. Checks 21 to 25 are clean. `git diff --check` exit 0. The working tree touches only Write Scope paths.
- **Fresh Primary baseline, read-only:** project URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`; ledger 249 `323eae75c4a400b4cc6f13317ec21611`, latest `20261010210000`, the target absent by version and name, no row after it; `parity_surface.sql` functions `724baac791a6a79c7d4328835d800f50`/323, triggers `a46035c1b6ce74d5d87fa46a40571e16`/309, policies `b67d466a…`/125, constraints `cea733ef…`/525, grants `6727f6d8…`/189, columns `448db887…`/1134, views `10bb212a…`/16, indexes `22a4d58c…`/300, status transitions `db2165c7…`/115, RLS `c117cbf7…`/79, combined `5a9ed7ff90852acec9a128b7fe4f8c5a`/3115; `complaints` has the 7 enabled triggers `derive_created_by`, `enforce_archive_authority`, `enforce_catalog_codes`, `enforce_status_transition`, `enforce_subscription_write_gate`, `guard_write_capability`, `set_updated_at`; `app.create_complaint` prosrc md5 `64e9efb36ff9ed32680c97057136d90c` and `app.advance_complaint` `c8b8193891bc4517ef510feb7de29991`, both SECURITY INVOKER, `search_path=""`, ACL `{postgres=X/postgres,authenticated=X/postgres}`; the three new functions are absent; 0 tenants, complaints and events.
- **Predicted delta:** one ledger row (250, `24b8778b…`, latest `20261011090000`); functions → `3d7eb4e3…`/326, triggers → `61f9789b…`/312, combined → `a23669c9…`/3121; the other eight surfaces unchanged; no business row.

### 2026-10-11 — Human Gate 2: owner authorization

The owner's SPEC-262 exact-identity approval (2026-10-11) grants a separate, advance, one-time, exact-byte Gate 2: deploy only `supabase/migrations/20261011090000_a_complaint_begins_new_under_its_creator.sql`, SHA-256 `55d54a8a26265f6ea7aaee3708906ca4c25d9ae79cbe4ab831ff17278adecb02`, MD5 `43ed834051349c20b746b721236b639a`, 15,136 bytes, LF, to Primary `vrvtsxexkiiiivlkdxzp` only, conditional on every mandatory readiness check passing; no other migration and no business-data change is authorized, and Secondary is never contacted. Its conditions hold as recorded in the entry above: the frozen bytes exist in the scratchpad and in the repository and match in full; the Draft contract, Write Scope and other frozen artifacts match; the readiness checks passed with only the drift the contract names; the Primary baseline was read independently, the target is absent, and the predicted effect is exact. Step 6 re-reads everything immediately before the write.

### 2026-10-11 — Step 6: Primary deployment

- **Local recheck, immediately before the write:**
  - HEAD `9fa595705fd59d078d538dac100bc6ccb3c5c2c8` on the chain `122fd65 → 2ca3f10 → 359cb5e → 9fa5957`, 0 behind `origin/main` `88bc20a`;
  - Draft `122fd65`'s contract hashes to `f3e4dedc…`, and since then this contract changed only its status lines and its Execution Log;
  - after the stash round trip the five Step 1–3 files hash to their recorded values: migration `55d54a8a…` (MD5 `43ed8340…`, 15136 bytes, 311 LF, 0 CR), test 154 `7045e732…`, test 83 `2aa3576c…`, register `e8ad4552…`, disposition record `494a94ca…`; the scratchpad copy of the migration hashes to the same value;
  - the working tree touches only Write Scope paths, and the stash is empty.
- **Primary recheck, read-only:** project URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`; ledger 249 `323eae75c4a400b4cc6f13317ec21611`, latest `20261010210000`, the target absent by version and name, no row after it; `complaints` with its 7 triggers; `app.create_complaint` prosrc `64e9efb3…` and `app.advance_complaint` `c8b81938…`; the three new functions absent; 0 tenants, complaints and events.
- **Server-side proof:** the transmitted text hashed on Primary to MD5 `43ed834051349c20b746b721236b639a`, 15136 bytes, 311 LF, 0 CR.
- **Apply:** that same text, through the Primary connector's `apply_migration`, returned success, once. A fresh read showed one new row, temporary version `20261011012026`, with one stored statement (MD5 `43ed8340…`, 15136 bytes), and 250 rows in all; the other 249 still hashed to `323eae75…`.
- **Reconciliation:** one guarded UPDATE renamed only that row to `20261011090000`, and it renamed 1 row. Every guard held:
  - 250 rows;
  - exactly one row after `20261010210000`;
  - the other 249 hashing to `323eae75…`;
  - one stored statement, its MD5 equal to the file's;
  - no existing target.
- **Fresh post-write reads (`2026-10-11T01:21:19Z`):**
  - ledger 250 `24b8778b6d9e955a8472affb07712858`, latest `20261011090000`, exactly one row for the migration, the temporary version gone;
  - functions `3d7eb4e3550f7cec15815defb600272d`/326 (both Check L2/P2 and `parity_surface.sql`) and triggers `61f9789b320a4eb988542b83beee36ca`/312; policies `b67d466a…`/125, constraints `cea733ef…`/525, grants `6727f6d8…`/189, columns `448db887…`/1134, views `10bb212a…`/16, indexes `22a4d58c…`/300, status transitions `db2165c7…`/115 and RLS `c117cbf7…`/79 unchanged; combined `a23669c9c5c31f56bed4f7e8d265c534`/3121. Each equals the prediction;
  - `complaints` carries the 10 enabled triggers `derive_created_by`, `emit_created`, `emit_transition`, `enforce_archive_authority`, `enforce_catalog_codes`, `enforce_status_transition`, `enforce_subscription_write_gate`, `guard_integrity`, `guard_write_capability`, `set_updated_at`, identical to local;
  - the five functions: `app.advance_complaint` prosrc `3e50de12…` / definition `97f58f7b…`, `app.create_complaint` `d23d3b01…` / `6620bd34…`, `app.emit_complaint_created` `b1ba2f27…` / `7fe32e91…`, `app.emit_complaint_transition` `aaf9bb23…` / `b6ccfc44…`, `app.guard_complaint_integrity` `1c2c4979…` / `b7d7f288…`, each equal to local; all SECURITY INVOKER, owner `postgres`, `search_path=""`; the two RPCs keep ACL `{postgres=X/postgres,authenticated=X/postgres}` and the three new functions hold `{postgres=X/postgres}`;
  - the table: RLS on (not forced), 1 policy, grants `authenticated` INSERT, SELECT, UPDATE, unchanged;
  - 0 tenants, complaints and events. No business-data write.
- **Secondary** `brplkqmbzffpxqgkkdzo` was not contacted.

### 2026-10-11 — Step 7: evidence and measured state

- **The evidence file, `reports/evidence/primary-ledger-evidence.json`,** was written from the fresh post-write readings only: `read_at` `2026-10-11T01:21:19Z`; `repository_head` `9fa59570…`; 250 migrations, `24b8778b…`; functions `3d7eb4e3…`/326, structural `a23669c9…`/3121; the ledger list appends `20261011090000_a_complaint_begins_new_under_its_creator`. `check_primary_ledger.ps1` recomputes it and finds it equal to the repository's migration files.
- **Manifest:** `Live state` reads 250 migrations, latest `20261011090000`, and the new ledger, function and structural hashes and counts, verified and re-read 2026-10-11. It reads `Suite **154 files / 2868 assertions**`, with the HTTP clause unchanged (464). `supabase/tests` holds 154 files whose literal `plan(N)` values sum to 2868. Batch 6 coverage reads 40 of 78, all forty at `ADVERSARIAL`.
- **Register:** COMP-2 and COMP-3 read `DEPLOYED to Primary under separate exact-byte owner authorization`, with Cert `✅`, worded without a new date.
- **Generated artifacts:** `MASTER_API_CONTRACT.md` regenerates unchanged (`d28fb567…`; 80 RPC endpoints, 8 views, 74 tables). `ai-map.json` is regenerated and stored LF; only `generated_at` changed.
- **CI-only guard self-tests, on this deployed state:** cold-start 34 passed, 0 failed; future-date 18/0; primary-ledger 13/0; status-contradiction 33/0.
- **Runtime Checkpoint** is `DONE`.
- **Checks:**
  - `check_primary_ledger.ps1`: RECOVER-1 `CLEAN`;
  - `check_database_parity_evidence.ps1`: `DATABASE PARITY: CLEAN` and `PRIMARY PARITY EVIDENCE: CLEAN`;
  - repository consistency: `CLEAN`;
  - `git diff --check`: exit 0.

### 2026-10-11 — Post-deploy local certification

Canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` ran on the clean, committed HEAD `a87fa92` with nothing else running. It ran in VERIFY mode (`STATUS: In Progress`, `STEP: DONE`), with profiles DATABASE and REPOSITORY plus the declared `verify_care_journeys.ps1` and `verify_journey_branches.ps1`. It reported `LOCAL_CERTIFY: READY` in 8.1 min, and every mandatory verification passed in that run:
- reset; pgTAP Pass A; the care HTTP suite; the journey HTTP suite; pgTAP Pass B; smoke;
- `check_database_parity_evidence.ps1`, repository consistency, `git diff --check` and `check_primary_ledger.ps1`.

The four CI-only guard self-tests passed on the same committed content (Step 7). M1–M26 and the causal negative ran at Step 4 on the committed migration and test bytes, which are unchanged, so they were not repeated. Test 154's assertions are checked by both pgTAP passes.

**The implementation was published before Complete, because this contract's Review Gate asks for candidate CI, main CI and `REMOTE_CERTIFY: READY` on the exact SHA, and the Gate requires every Review Gate item checked at the Complete transition.** Checking that item before those facts existed would have been false, so the implementation SHA was published first with the existing mechanisms, and the Complete commit follows it and is published, CI-verified and certified again as Step 8 states:
- `-Gate -BaseRef origin/main` on `88bc20a..a87fa92` (In Progress): exit 0;
- `scripts/publish_candidate.ps1`: `a87fa92` → `orvion-preflight`; candidate CI on that exact SHA: Agent Control `38102949240`, Repository Consistency `38102949286`, Migration CI `38102949263` and ORVION Acceptance `38102949218` (16.1 min), all success on attempt 1;
- `main` fast-forwarded `88bc20a..a87fa92` by pushing that exact SHA; main CI: Repository Consistency `38103963732`, Agent Control `38103963772` and Migration CI `38103963744`, all success on attempt 1;
- `-Certify` at `a87fa92`, target `main`: `REMOTE_CERTIFY: READY`.

**Selector after SPEC-262** (`scripts/batch6_select_target.ps1`, 38 surfaces still `NOT-RECORDED`), as Exposure/coverage:
1. `payment_allocations` 8/60
2. `receipts` 7/20
3. `chart_of_accounts` 7/38
4. `notification_deliveries` 7/42
5. `approval_requests` 7/52
6. `user_branch_assignments` 7/578
7. `departments` 7/642
8. `user_role_assignments` 7/642
9. `customer_consents` 6/18
10. `document_retention_policies` 6/36
11. `document_links` 6/54
12. `exchange_rates` 6/60

Slice 40's measured target is `payment_allocations`.

## Verification Notes

### 2026-10-11 — Independent Review of the execution commit `a87fa92`

Reviewed the committed tree against the approved Draft `122fd65`, the owner's Gate-2 authorization and the ten-path Write Scope. The review read the implementation, the certified local stack and Primary, not the Execution Log.

1. **Creation under the creator (criterion 1).** The guard derives `owner_user_id`, `owner_branch_id` and `owner_department_id` from `app.current_user_id()` and `app.current_placement()` for a signed-in INSERT and refuses 42501 without an actor or branch. Test 154 assertions 3–6 (forged owner and filing replaced), 26 (the named colleague sees 0 rows) and 27 (no primary branch, 42501) passed in both `-Finish` pgTAP passes; mutants M7 and M8 are killed by them.
2. **No reassignment, no blank title (criterion 2).** The UPDATE arm refuses a signed-in change to any of the three scope columns and every caller's blank title (23514); assertions 12, 13, 14 (an ordinary edit succeeds) and 49 pin it; M11, M12 and M22 are killed.
3. **Entry state (criterion 3).** The INSERT arm requires `new` with null `resolved_at`, `closed_at` and `resolution_notes` and no archive field, before the session test, so it binds session-less creation too. Assertions 15–20, 30 and 48 pin it; M1–M6 are killed.
4. **The created event (criterion 4).** `complaints_emit_created` (AFTER INSERT, row, enabled, `tgtype` 5) records `complaint_created` at `warning` with the RPC's payload keys and the session's actor or null; `app.create_complaint` no longer records it. Assertions 7–11, 22, 32 and 34 pin one event per creation, its payload, the timeline and the absence of events for refused creations; M9, M10 and M25 are killed.
5. **Transition events (criterion 5).** `complaints_emit_transition` (AFTER UPDATE OF `complaint_status_code`, `WHEN` the status changes, `tgtype` 17) maps the entered state with a `case` and records `complaint_reopened` at `warning`, every other move at `info`, with the old and new states, the consumed reason and the actor. Assertions 24, 37, 44, 47 and 50 pin exactly one event per move on both doors and none for a no-op or field-only update; M13, M14, M21 and M23 are killed. The care HTTP suite passed inside `-Finish`.
6. **Server-owned times and note (criterion 6).** For a signed-in caller the guard stamps `resolved_at` and takes the trimmed `app.transition_reason` as `resolution_notes` on entering `resolved`, stamps `closed_at` on entering `closed`, clears it on entering `in_progress`, and otherwise keeps all three; session-less writes keep what they carry. Assertions 38, 40, 41, 45 and 51 pin it; M17, M18, M19, M20 and M26 are killed.
7. **The reasoned reopen (criterion 7).** The guard refuses `closed -> in_progress` without a non-blank reason; the producer clears the reason after each move. Assertions 39, 42, 43, 45 and 46 pin it; M15, M16 and M24 are killed.
8. **RPC fidelity (criterion 8).** Extracted from the committed files, `app.create_complaint` differs from its only earlier definition (`202607051500`) by the six-line `record_event` call alone, and `app.advance_complaint` from its only earlier definition (`202607057000`) by its `v_actor` declaration, its actor lookup replaced by `perform set_config('app.transition_reason', coalesce(p_reason, ''), true)`, and its removed `record_event` call; its transition map, permission charge and UPDATE are byte-identical. On Primary and the certified local stack both keep SECURITY INVOKER, owner `postgres`, `search_path=""` and ACL `{postgres=X/postgres,authenticated=X/postgres}`.
9. **Held controls (criterion 9).** Assertions 21 (rival tenant, 42501), 28–29 (trainee, 42501) and 31 (session-less nullable owner) passed; tests 32 (11/11) and 54 (6/6) passed in both full passes, and `parity_surface.sql`'s status-transition surface is unchanged (`db2165c7…`/115) on both sides.
10. **Mutation (criterion 10).** M1–M26 ran at Step 4 against the reset stack carrying the committed migration, with test 154's committed bytes: base surface `10856b75…`, every installation changed it, every rollback restored it, all twenty-six killed with their frozen assertions. The causal negative (35 failures, the frozen list) was measured on the unrepaired 249 stack with the committed test 154.
11. **Test 83 (criterion 11).** Its diff against `88bc20a` is one line, identical after removing `complaints.owner_user_id, `; it passed 23/23.
12. **Records (criterion 12).** The register holds COMP-2 and COMP-3 after SR-2, Medium, FIXED and DEPLOYED with Cert `✅`, Owner `—`. ENTRY-1's and ARCH-2's rows keep their prior text as an exact prefix and append their SPEC-262 entries. COMP-1, SR-1 and SR-2 are unchanged.
13. **Disposition (criterion 13).** Against `88bc20a` the record changed its freshness entry, the coverage line, "All 40" and the `complaints` row only. Its rows count 17 `AUDITED`, 20 `AUDITED-OPEN`, 3 `PARTIAL` and 38 `NOT-RECORDED`: 40 of 78.
14. **Frozen values (criterion 14).** The committed blobs hash to the approved values: migration `55d54a8a26265f6ea7aaee3708906ca4c25d9ae79cbe4ab831ff17278adecb02`, test 154 `7045e732…`, test 83 `2aa3576c…`. Primary's stored statement MD5 is `43ed834051349c20b746b721236b639a`.
15. **Agreement (criterion 15).** Primary, the evidence and the manifest agree: 250 migrations, `24b8778b…`; functions `3d7eb4e3…`/326, structural `a23669c9…`/3121; 154 files / 2868 assertions (plan sum recounted); 464 HTTP assertions. The API contract matches its generator (`d28fb567…`), and `ai-map.json` is LF. The four guard self-tests passed on the deployed content, and `-Finish`'s parity, ledger and consistency checks passed.
16. **Next capability (criterion 16).** The Complete commit names Batch 6 Slice 40 and `payment_allocations` (8/60), which the selector measured on the certified stack, and clears the Active Change Request.
17. **Primary and Secondary (criterion 17).** Primary's ledger holds exactly one row for the migration, after one guarded rename of temporary version `20261011012026`; it holds 0 tenants, complaints and events before and after; only the function and trigger surfaces moved. Secondary was never contacted.
18. **Scope (criterion 18).** `88bc20a..a87fa92` changes nine paths, all in Write Scope; `MASTER_API_CONTRACT.md` regenerates unchanged.

**Review Gate, item 6 (CI and remote certification):** candidate CI on the implementation SHA `a87fa92` ran and succeeded on attempt 1 (Agent Control `38102949240`, Repository Consistency `38102949286`, Migration CI `38102949263`, ORVION Acceptance `38102949218`); `main` was fast-forwarded to that exact SHA and its CI succeeded (Repository Consistency `38103963732`, Agent Control `38103963772`, Migration CI `38103963744`); `-Certify` read those runs from GitHub and returned `REMOTE_CERTIFY: READY`. The Complete commit is published, CI-verified and certified again under Step 8.

**Outside this contract, and not a defect in it:**
- Customer–booking coherence is accepted by both doors and stated by no canon rule; recorded in the disposition row.
- TRANS-1's duplicated transition map stays as it was.

Verdict: Confirmed Complete

## Review Gate

- [x] Every Acceptance Criterion is proven against the live repository and runtime, not the Execution Log.
- [x] The committed migration, test 154 and test 83 match their frozen SHA-256 values.
- [x] Mutants M1–M26 and the causal negative are recorded.
- [x] Primary was written only under separate exact-byte owner authorization, and Secondary was never contacted.
- [x] Repository, local stack and Primary agree on the ledger, function surface and structural surfaces.
- [x] Candidate and main CI passed on the exact SHA, and `REMOTE_CERTIFY: READY`.
- [x] No file outside Write Scope changed.

## Notes

Batch 6 Slice 39, prepared under the owner's 2026-10-11 Slice 39 directive. Gate 1 approval of this exact Draft and Gate 2 authorization of the migration's exact SHA-256 are each the owner's decision.
