# Change Request — SPEC-257

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Foundation Completion Programme Batch 6 Slice 35: give `public.service_requests` a truthful disposition and close **SR-1** and **SR-2**.

The surface is canon 24's Service Request: operational work a customer asks for after booking, linked to the customer and optionally to the booking or booking item it concerns. `authenticated` holds table-level INSERT, SELECT and UPDATE, and both RPCs, `app.create_service_request` and `app.advance_service_request`, are SECURITY INVOKER through that same grant, so PostgREST serves the table beside them.

After this change one invariant holds on both doors: **a service request begins `requested`, unresolved and unarchived, titled, owned and filed by whoever opens it, with exactly one `service_request_created` event; no signed-in UPDATE moves its owner or filing scope afterwards; every change of its status records exactly one canon-26 event; its resolution time is the server's; and a closed request is reopened only with a reason.**

Record the surface `AUDITED` and close this surface's instances of **ENTRY-1** and **ARCH-2**.

This contract does not touch any permission charge, state transition, grant or policy, canon 26, 27, 28 or 29, any other surface, n8n or any Phase-8 work.

## Business Reason

### Selection
`scripts/batch6_select_target.ps1` at `3af104b` ranks `service_requests` first: `NOT-RECORDED`, Exposure 8, coverage 34, 7 test files, 2 direct writes, no SECURITY DEFINER function, 2 RPCs and 1 state signal. The runner-up is `quotation_items` at 8/36. The 7 test files only name the table in catalog sweeps and fixtures; no pgTAP file calls either RPC.

### Authority
- **Canon 26 (Service Request State Machine):** the states are `requested`, `in_progress`, `awaiting_customer`, `awaiting_supplier`, `resolved` and `closed`; the normal flow starts at `requested`; `closed -> in_progress` is "reopened with reason by authorized user"; its required events are `service_request_created` and one for every transition (`_in_progress`, `_awaiting_customer`, `_awaiting_supplier`, `_resolved`, `_closed`, `_reopened`). Its Transition Enforcement section states that the status trigger checks only validity and authority, not the RPCs' events, reasons or timestamps.
- **Canon 27:** every important business action creates an event that identifies its actor and time; `service_request_created` is info; `service_request_reopened` is a **warning** and requires a reopen reason and an authorized actor.
- **The sole sanctioned lifecycle writer, `app.advance_service_request`** (`202607050900`): it charges RESOLVE_SERVICE_REQUEST on every edge, stamps `resolved_at` with `now()` only on entering `resolved` and otherwise keeps it, takes no resolution time from its caller, and records each transition's event with the caller's reason.
- **SPEC-237** (`20260928160000`, CONV-8) gave a business act one AFTER-trigger producer for both doors, with its RPC handing the caller's reason through the transaction-local `app.transition_reason`, which the producer consumes.
- **Canon 29:** a Customer has many Service Requests; a Service Request may optionally link to the Booking or Booking Item it concerns.
- **The sole sanctioned writer, `app.create_service_request`** (`202607051500`): it charges CREATE_SERVICE_REQUEST, writes `requested`, owns the request as the caller, files it under `app.current_placement()`'s branch and department (refusing a caller with no primary branch), and emits `service_request_created`.
- **Archiving** is the UPDATE `app.enforce_archive_authority` charges ARCHIVE_RECORD for. No RPC creates a service request archived.
- **ENTRY-1** (OPEN, engineering): the state machine governs every move except the first; `service_requests` is one of five tables left, to be closed per surface. **ARCH-2** (OPEN, engineering): the archive guard never fires on INSERT; `service_requests` is one of eleven tables left, each to be proven in its own slice.
- **SPEC-220** (`20260924170000`) closed the same shape on `conversations` (CHAT-1): a SECURITY INVOKER BEFORE INSERT guard and one AFTER INSERT event producer.

### SR-1 (Medium) — a request created at the table door could be born closed or archived, owned by someone else, and leave no event
Measured at `3af104b` on the local stack in rolled-back transactions, by an `employee` placed in Main / Sales, proven first (`current_user`, `auth.uid()`) to hold CREATE_SERVICE_REQUEST and RESOLVE_SERVICE_REQUEST and not ARCHIVE_RECORD:
- **Born closed:** a direct INSERT created a request `closed` with `resolved_at` 2020-01-01.
- **Born archived:** a direct INSERT created a request with `is_archived` true, `archived_by` a colleague and `archive_reason` 'forged narrative'.
- **Someone else's request:** a direct INSERT filed under the employee's branch named a colleague in another branch as owner. It persisted, and that colleague then read the row through owner-based RLS.
- **No event:** none of those rows emitted `service_request_created`. The same actor's RPC wrote `requested`, owned and filed under itself, with one event.
- **No branch:** test 149 shows an employee with no primary branch assignment creating a request directly, which the RPC refuses.
- **Two statements to the same exposure:** after a legitimate RPC creation, the same employee moved the owner to a colleague in another branch, or the filing scope to another branch, by a direct UPDATE, and that branch's colleague then read both requests. A same-department colleague took a request over the same way. No event recorded either move. No RPC moves a service request's owner or filing scope, and canon 28 defines no reassignment act or permission for one (CREATE, RESOLVE and VIEW_SERVICE_REQUEST only).

A request is customer work. Its owner and branch decide who sees it and who answers for it, a request born closed never appears as open work, and one born archived carries a narrative nobody was authorized to write.

### SR-2 (Medium) — after creation, a request's life could be lived at the table door without its events, with a forged resolution time, and reopened without a reason on both doors
Measured at `3af104b` by the same employee, who also holds RESOLVE_SERVICE_REQUEST, and measured again on SR-1's repaired prototype (test 149 assertions 35–48 below, eleven failing there):
- A legal direct UPDATE walked a request `requested -> in_progress -> resolved -> closed` with no transition event and `resolved_at` forged to 2001-01-01. A later UPDATE rewrote `resolved_at` to 2019-05-05 with no status change.
- A direct UPDATE reopened `closed -> in_progress` with no reason. So did `app.advance_service_request` with a null `p_reason`, and its `service_request_reopened` event was severity `info`.
- Session-less moves left no event.
- The table accepted a blank title, which the RPC refuses.

`app.status_transitions` refused none of it: it owns each edge and its permission, and canon 26 says so. The authority was already held, so nothing escalates; what was falsifiable was the record of what happened and when. Any of the six roles holding RESOLVE_SERVICE_REQUEST could do it, and the customer timeline lost the request's history. That is SUP-5's grade for a silent table-door act its RPC records: Medium. `resolved_at` has one sanctioned writer, which stamps the server's time on entering `resolved` and accepts no other value, and no canon rule gives it a business-effective date. A historical import is a session-less platform write, and keeps its latitude.

### The repair
One migration, in SPEC-220's and SPEC-237's shapes:
- `app.guard_service_request_integrity()`, SECURITY INVOKER with an empty `search_path` and PUBLIC EXECUTE revoked, is attached as the row-level BEFORE INSERT OR UPDATE trigger `service_requests_guard_integrity`, the shape of `app.guard_document_integrity` (SPEC-216).
  - For every caller it refuses a blank title (23514), as the RPC does.
  - On UPDATE, for a signed-in caller only:
    - it refuses a change to `owner_user_id`, `owner_branch_id` or `owner_department_id` (23514): what no sanctioned writer ever changes, the table door cannot change either;
    - it refuses `closed -> in_progress` unless a non-blank `app.transition_reason` is present (23514);
    - it sets `resolved_at` to `now()` on entering `resolved` and otherwise keeps the stored value, which is what the sanctioned writer does.
  - Every other UPDATE passes through untouched, and session-less platform writes are exempt from the UPDATE arm.
  - On INSERT, for every caller it requires `requested` with a null `resolved_at`, and no archive field (23514).
  - For a signed-in caller it resolves `app.current_user_id()` and `app.current_placement()`, refuses with 42501 when there is no actor or branch, and derives `owner_user_id`, `owner_branch_id` and `owner_department_id`.
  - Session-less platform writes keep their nullable owner.
- `app.emit_service_request_created()`, with the same security, is attached as the row-level AFTER INSERT trigger `service_requests_emit_created`.
  - It calls `app.record_event` with the RPC's exact event type, entity, state and payload keys (`customer_id`, `service_request_type_code`).
  - The actor is the session's user, or null.
- `app.emit_service_request_transition()`, with the same security, is attached as the row-level AFTER UPDATE OF `service_request_status_code` trigger `service_requests_emit_transition`, `WHEN` the status changes.
  - It records canon 26's event for the state entered, `service_request_reopened` for `closed -> in_progress`, with the old and new states and the reason from `app.transition_reason`, which it consumes.
  - The severity is `warning` for the reopen (canon 27) and `info` otherwise. The actor is the session's user, or null.
- `app.create_service_request` is replaced by its complete current definition, minus only its `app.record_event` call.
- `app.advance_service_request` is replaced by its complete current definition, with its `app.record_event` call replaced by `set_config('app.transition_reason', coalesce(p_reason, ''), true)` before its UPDATE, and the actor lookup that only that call used removed.
- Both RPCs keep their signature, SECURITY INVOKER, `search_path` and `authenticated` EXECUTE. The transition map, permission charge and UPDATE of `app.advance_service_request` are unchanged.

No table, column, grant, policy, permission, event type, catalog value or state transition is added. Time is `now()`, the transaction's timestamp, which is what the RPC already uses.

### Rejected
- **Widening `service_requests_enforce_archive_authority` to INSERT:** it would authorize and stamp an archive at creation, which no RPC does. Refusing at entry is what `documents` chose for ARCH-2 (SPEC-216).
- **An entry-state row in `app.status_transitions`:** ENTRY-1 weighed and declined promotion three times, because it changes INSERT behaviour on surfaces no slice has read.
- **Revoking INSERT from `authenticated`:** the RPC is SECURITY INVOKER and inserts through that grant. Making it a definer would move its RLS and capability semantics, which is a larger change than the defect.
- **Charging a permission for reassignment:** canon 28 defines none for service requests, and choosing one would be policy. Refusing the move is the fail-closed reading of the sole sanctioned writer, and canon 28's owner-ratified note 1 already lets a department colleague continue a request when its owner is absent, without reassignment. A reassignment act, if canon ever defines one, needs its own contract.
- **A second guard for the owner, reopen or resolution-time rules:** the creation guard already fires on UPDATE and owns the request's integrity, so each rule is a few lines in it.
- **Deferring SR-2 to a later slice:** the same table, guard, migration and test carry it, so a separate contract would cost a second approval, a second Primary deployment and a second certification for a few lines. SPEC-237 has already designed the lifecycle-authority shape that the trigger awaited.
- **Refusing a forged `resolved_at` instead of stamping it:** a client echoing back the stored value, or entering `resolved` without knowing the server's clock, would be refused. The server stamping its own time is what `app.enforce_archive_authority` does for archive metadata and what `app.record_event` does for events.
- **Making the transition trigger refuse every direct status change:** it would remove the legal, authorized table-door edges canon 26 Transition Enforcement keeps. Recording them is enough.
- **A transition-event mapping table (`values … as t(...)`) in the producer:** tests 07, 08 and 54 read such a block as a transition RPC. A `case` keyed by the state entered maps the same eight edges.
- **An outbox, event bus or pgAudit:** `app.record_event` writes in the same transaction as the change, so a refused or rolled-back move leaves no event. Nothing here is delivered outside the database.
- **Clearing `resolved_at` on reopen:** the sanctioned writer keeps it, and no canon rule says otherwise.

### Held, recorded so a later slice does not rediscover it
- **The UPDATE door's edges:** `app.status_transitions` charges RESOLVE_SERVICE_REQUEST on every status change. CREATE_SERVICE_REQUEST and RESOLVE_SERVICE_REQUEST are held by exactly the same roles (owner, ceo, branch_manager, department_manager, senior_employee, employee), so `guard_write_capability`'s either-permission rule on UPDATE escalates nobody.
- **Capability:** a trainee without CREATE_SERVICE_REQUEST is refused at the table (42501).
- **Tenant:** a row under another tenant is refused by RLS. A foreign customer, booking or item is refused by the tenant-qualified foreign keys. There is no DELETE grant.
- **Customer–booking coherence:** both doors accept a request under one customer naming another customer's booking in the same tenant. No canon rule states coherence, and no surface in the repository enforces it, so it is recorded here and not invented.
- **Archive authority after creation:** `requested -> closed` is refused by the status trigger, and archiving, the archiver and the archive reason each still cost ARCHIVE_RECORD on UPDATE. Re-measured: all three were refused to the employee, and a branch manager's archive was stamped by the server.

## Risks

- **Changed INSERT semantics.**
  - A signed-in direct INSERT now gets the creator's own owner and placement, whatever it supplies.
  - A non-`requested`, resolved or archived entry is refused for every caller.
  - Nothing legitimate creates either today: the only session-less writer is test 111's `requested` fixture, there is no seed, and both HTTP suites that create requests use the RPC.
- **Signed-in reassignment stops.** A CREATE or RESOLVE holder can no longer move a request's owner or filing scope at the table. No RPC or HTTP suite does it, and no canon act defines it; department visibility covers an absent owner. The platform's session-less path keeps it.
- **The events move.** Each successful INSERT emits `service_request_created` once, from its trigger, and each change of status emits its transition event once, from its trigger. Neither RPC emits them itself. A refused INSERT or move emits nothing, and a no-op or field-only UPDATE emits nothing. Test 149 pins exactly one event per act on each door. The HTTP lifecycle suite's request, advanced four times through the RPC, carried exactly four transition events with their reasons and actor.
- **Changed UPDATE semantics.**
  - A signed-in `resolved_at` is the server's: stamped on entering `resolved`, kept otherwise, whatever the statement supplies.
  - A closed request is reopened only with a reason, on both doors. A direct PostgREST UPDATE cannot hand a reason, so a signed-in reopen goes through `app.advance_service_request(..., p_reason)`, which already offers it.
  - A blank title is refused for every caller.
  - `service_request_reopened` is now severity `warning`, as canon 27 states.
  - No HTTP suite, seed or other test reopens a request or writes a blank title. Every HTTP RPC call already passes a reason.
- **The attribution inventory.** Test 83 assertion 23 pins the users-FK columns that no BEFORE trigger derives. The new guard derives `service_requests.owner_user_id`, so exactly that member leaves the expected list. Its query, assertion 22 and every other member stay unchanged. This is the consumer whose omission cancelled SPEC-219.
- **The transition and event parsers.** Tests 07, 08, 32 and 54 read app functions' text. The producer uses a `case`, not a `values … as t(...)` block, and every status it compares with `=` is a registered destination. All four pass unchanged on the prototype.
- **Primary deployment** adds three functions and three triggers and replaces two function bodies, and nothing else. It requires separate exact-byte owner authorization (Gate 2); approving this contract does not authorize it. Primary holds no service requests.
- **Workstation, not in scope:** resets for this contract run from the main checkout. A reset from a scratch git worktree leaves local storage without `bucketid_objname`.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-257-a-service-request-begins-requested-under-its-creator.md`
- `supabase/migrations/20261010120000_a_service_request_begins_requested_under_its_creator.sql`
- `supabase/tests/149_a_service_request_begins_requested_under_its_creator_test.sql`
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
- `supabase/migrations/20260924170000_conversation_creation_parity.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/32_lifecycle_transition_test.sql`
- `supabase/tests/54_transition_permission_parity_test.sql`
- `supabase/tests/58_write_grants_and_config_capability_test.sql`
- `supabase/tests/67_care_capability_and_message_integrity_test.sql`
- `supabase/tests/85_write_capability_on_update_test.sql`
- `supabase/tests/111_customer_surface_test.sql`
- `supabase/tests/125_conversation_creation_parity_test.sql`
- `reports/architecture-decision-records.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/24_entity_registry.md`
- `_ORVION_CANONICAL/26_state_machines.md`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `_ORVION_CANONICAL/29_relationship_map.md`
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
- `_ORVION_CANONICAL/26_state_machines.md` (Service Request State Machine); `_ORVION_CANONICAL/27_event_catalog.md` (Service Request Events); `_ORVION_CANONICAL/28_permissions_matrix.md` (CRM permissions and read scope); `_ORVION_CANONICAL/29_relationship_map.md` (Customer To Service Request)
- `reports/master/MASTER_GAP_REGISTER.md` (ENTRY-1, ARCH-2, CHAT-1, CHAT-2, SUP-5); `reports/master/MASTER_SURFACE_DISPOSITION.md`; `reports/master/MASTER_EXECUTION_PLAN.md` Batch 6 method and EC-1…EC-11
- `supabase/migrations/202607050900_customer_service_write_paths.sql`; `supabase/migrations/202607051500_branch_filed_write_paths.sql`; `supabase/migrations/20260924170000_conversation_creation_parity.sql`; `supabase/migrations/20260928160000_a_qualified_lead_and_a_booking_are_recorded_on_every_door.sql`
- Current local `app.create_service_request`, `app.advance_service_request`, `app.record_event`, `app.current_placement`, `app.guard_write_capability`, `app.enforce_status_transition`, `app.enforce_archive_authority`
- Tests 07, 08, 32, 54, 83 (assertion 23), 111 and 125

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

- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A signed-in INSERT is `requested`, unresolved, unarchived and titled, owned and filed by its creator | `scope_isolation` RLS; `app.advance_service_request`; `app.status_transitions`; `app.enforce_archive_authority` | WRITE | The prototype was a scratch worktree at `3af104b`, with the migration applied with its ledger row on a stack reset from the main checkout. Migration SHA-256 `2da54597b05972dbb12d75c9ce0fc2600a9d610ed86664d859e85dba6ddfed0b`, md5 `351e1ac51761c1b9a62133e381b072a3`, 14009 bytes, 287 LF lines, ASCII. A forged owner and a forged filing scope were replaced by the creator's own; the colleague in the other branch then saw 0 rows. Closed, resolved, archived, archiver-named and blank-titled entries were refused 23514. An employee with no primary branch was refused 42501. |
| A signed-in UPDATE keeps the owner, filing scope and title, takes the server's `resolved_at`, and reopens only with a reason | `app.advance_service_request`; `app.status_transitions`; `app.enforce_archive_authority`; `guard_write_capability` | WRITE | After creation, a signed-in move of the owner or filing scope, a blanked title, and a reopen with no reason (direct, or through the RPC with a null `p_reason`) were each refused 23514, while an ordinary edit succeeded. `resolved_at` forged to 2001-01-01 while resolving, and to 2019-05-05 afterwards, each gave way to the server's `now()`. The RPC's own reopen with a reason succeeded. Every edge, its permission and the archive charge are unchanged: test 32 (11/11) and test 54 (6/6) pass unchanged. |
| The created and transition events move from the RPC bodies to AFTER producers | `public.events`; `app.customer_timeline`; `verify_journey_branches.ps1` and `verify_lifecycle_branches.ps1` (RPC creation and four RPC transitions) | WRITE | Before: a direct creation or move emitted 0 events, and each RPC act emitted 1. Prototype: each direct and RPC creation emitted exactly 1, with the RPC's payload and the creator as actor, and reached the customer timeline. Each direct and RPC move emitted exactly 1, with its states, its reason and its actor; the reopen was a `warning`. A refused act, a no-op status UPDATE and a field-only UPDATE emitted none, and a reason handed to one transition opened no other. Both HTTP suites pass unchanged (85/0 and 122/0). Afterwards, the lifecycle suite's request carried its created event and exactly four transition events, each with the reason the suite passed, and its `resolved_at` equalled its resolved event's time. |
| The event and status vocabulary guards | tests 07, 08, 32, 54 (they read app functions' text) | VERIFY | The producer maps states with a `case`, not a `values … as t(...)` block, and every status it or the guard compares with `=` (`closed`, `in_progress`, `resolved`) is a registered destination. `app.advance_service_request`'s transition map is byte-identical. On the prototype: 07 2/2, 08 2/2, 32 11/11, 54 6/6. |
| Session-less INSERT and UPDATE | test 111's fixture; future platform writers, including a historical import | VERIFY | The entry state binds a session-less write too (a session-less `closed` creation is refused 23514), and the title rule precedes the guard's session test. A session-less `requested` creation keeps its null owner and emits once with a null actor. Session-less moves emit once each with a null actor and keep the `resolved_at` they carry. Test 111 passes unchanged (57/57). |
| Creation ownership becomes trigger-derived and fixed against signed-in UPDATEs | `83_actor_attribution_test.sql` assertion 23 | WRITE | Its query lists users-FK columns that `authenticated` can write and no BEFORE trigger derives. The guard removes `service_requests.owner_user_id` from that measured set, and on the prototype only assertion 23 failed until exactly that member was removed. Test 83: SHA-256 `868ecc18194cd7e7e12add2f60eb336cee342a2b411ddc08e789892ce568bc62`, 21202 bytes → `16235efe12063c32dcfe0107c8f6423f4349df8f6d3eed246e7f6b90dd2f4a34`, 21170 bytes, a one-line diff deleting `service_requests.owner_user_id, `. Then 23/23. |
| Test 149 | `supabase/tests` | WRITE | SHA-256 `8e69bab0610d83a196644abbf4e3ce53df06f61bcd498e7d56790a27766ca7e4`, `plan(48)`, 22752 bytes, 270 LF lines, ASCII: 48/48 on the prototype. On the unrepaired `3af104b` schema 31 fail, each for its intended reason: 5, 6, 7, 8, 9, 12, 13, 15, 16, 17, 18, 20, 24, 25, 28, 30, 31, 32, 33, 34, 35, 36, 37, 38, 40, 41, 43, 44, 45, 47, 48. With SR-1's repair alone (the Draft at `98f2936`, migration `67d8c76e…`), exactly SR-2's 11 fail: 35, 36, 37, 38, 40, 41, 43, 44, 45, 47, 48. |
| Other tests reading this table or its functions | tests 10, 52, 53, 58, 67, 85, 125 | VERIFY | Each passes unchanged on the prototype: 9/9, 15/15, 12/12, 27/27, 25/25, 16/16, 31/31. |
| The generated API contract | `MASTER_API_CONTRACT.md` | WRITE | The canonical generator against the prototype reports 80 RPC endpoints (80 with HTTP evidence), 8 views and 74 tables. It is byte-identical to the committed contract (SHA-256 `d28fb5672ca9c0795a99a74746069c973e1392edcc5e3d2a5a315348138175fd`): no grant, table or client RPC moves. Step 7 regenerates it, and it stays unchanged. |
| Suite, HTTP and smoke | full pgTAP; the six HTTP suites; `scripts/verify_database.sql` | VERIFY | On the prototype, in `-Finish`'s order on a main-checkout reset: pgTAP Pass A 149 files / 2745 assertions PASS (2697 + 48); HTTP 35 + 40 + 85 + 122 + 122 + 60 = 464 passed, 0 failed; Pass B 149 / 2745 PASS; smoke `ALL CHECKS PASSED (78 tables, … 71/622 catalog, …)`; plan sum 149 / 2745. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | The local reset equalled the recorded Primary values (245 migrations, `43bf5befaf466ec422d8eaaf5261d250`; functions `258738c5fea4dd5ff1040cf65997390b`/320; triggers `d07aa82d8ce6e3d8b3adba9310ba657f`/306; combined `902311907ba7e192b285bd43e091ff8d`/3109). With the migration, functions became `e3d5180863b8482178efde66465a47b4`/323, triggers `a46035c1b6ce74d5d87fa46a40571e16`/309 and combined `f56111d6426fb29d91ff6cb41ce1ada2`/3115. Policies, constraints, grants, columns, views, indexes, status transitions and RLS each equal the recorded Primary value. The 246-file ledger fingerprint is `a6500a25aeb035493ac37f18cb46fb32`. |
| Measured state that moves | manifest (`Live state`, suite figure, coverage, Last Completed, Current Module, Next capability); `primary-ledger-evidence.json`; `ai-map.json` | WRITE | 245 → 246 migrations, latest `20261010120000`; 148 → 149 files and 2697 → 2745 assertions; coverage 35 → 36 of 78. HTTP (464), tables (78), catalog (71/622), views (8) and client RPCs (80) do not move. Primary values are written only from fresh post-deploy readings. |
| SR-1 and SR-2 fixed, ENTRY-1 and ARCH-2 annotated; the surface `AUDITED` | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24, 25 | WRITE | Test 149's `-- ATTACK-CLASSES:` line and negative assertions satisfy Check 24 for `service_requests`. SR-1's and SR-2's Owner field is `—`, so Check 25 reads no owner decision. The disposition row names this contract as its session, and the coverage line becomes 15 `AUDITED` and 18 `AUDITED-OPEN`. On the prototype, Checks 21, 22, 24 and 25 pass. |
| CI-only guard self-tests and repository consistency | `scripts/test_*_guard.ps1` (four); `scripts/check_repository_consistency.ps1` | VERIFY | On the prototype, future-date (18/0) and status-contradiction (33/0) pass. Primary-ledger (11 passed, 2 failed) and cold-start (25 passed, 9 failed) fail ONLY their CONTROL and restore cases, which require an untouched copy of the repository to be CLEAN; every mutation case passes. Repository consistency reports exactly the pre-deploy measured-state drift: `manifest says 245 migrations, repository holds 246`; latest `20261009120000` vs `20261010120000`; ledger fingerprint `43bf5bef…` vs `a6500a25…`; `148 test files` vs 149; `2697 assertions` vs 2745; RECOVER-1 ledger evidence. Checks 21 to 25 are clean. These are not waived: Step 7 makes them true, and Step 8 requires them green. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused tests, pgTAP A/B, the six HTTP suites, smoke and mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| SR-1, SR-2, ENTRY-1, ARCH-2 and the disposition describe the local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |
| The four CI-only guard self-tests pass | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: `app.enforce_status_transition` fires on UPDATE only and judges each edge and its permission, not its event, reason or time (canon 26 Transition Enforcement). `app.enforce_archive_authority` fires on UPDATE only. `app.guard_write_capability` charges CREATE_SERVICE_REQUEST (or RESOLVE_SERVICE_REQUEST on UPDATE) but checks no entry state, creator, owner move, title, resolution time, reason or event. RLS judges scope against caller-supplied owner fields, so a creator's WITH CHECK passes for a move it makes itself. Only the RPCs supply the correct values and events. This contract reuses `app.record_event`, `app.current_placement()`, `app.current_user_id()`, the capability trigger, the status trigger, the existing RLS and foreign keys, and SPEC-237's `app.transition_reason` hand-off. No shared entry, lifecycle or event framework is earned (ENTRY-1 declined promotion three times).

Added Property: A successful INSERT through either door begins `requested`, unresolved, unarchived and titled, under the actual creator and placement for a signed-in caller, and emits exactly one `service_request_created` with the RPC's payload. Afterwards no signed-in UPDATE moves the owner or filing scope or blanks the title. Every change of status through either door emits exactly one canon-26 event with its states, reason and actor, and the reopen is a `warning`. A signed-in caller's `resolved_at` is the server's. A closed request is reopened only with a reason. A refused act emits nothing.

Causal Negative: These are the pre-repair measurements in Business Reason, at `3af104b`:
- direct creation `closed` with `resolved_at` 2020-01-01;
- direct creation archived with a colleague as `archived_by` and a forged reason;
- direct creation naming a colleague in another branch as owner, readable by that colleague;
- zero `service_request_created` events for every direct creation;
- after a legitimate creation, a direct UPDATE moving the owner or filing scope to another branch, which that branch then read;
- a direct walk to `closed` with no transition event and a forged `resolved_at`, then `resolved_at` rewritten alone;
- a reopen with no reason, through the table and through the RPC, the RPC's event at severity `info`;
- a blank title accepted at the table.

On the unrepaired schema, test 149 fails assertions 5, 6, 7, 8, 9, 12, 13, 15, 16, 17, 18, 20, 24, 25, 28, 30, 31, 32, 33, 34, 35, 36, 37, 38, 40, 41, 43, 44, 45, 47 and 48, each for its intended reason. With SR-1's repair alone, exactly 35, 36, 37, 38, 40, 41, 43, 44, 45, 47 and 48 fail. The causes are:
- the forged owner or filing kept, at creation or by a later UPDATE;
- no event at creation or on a move;
- the forged resolution time kept;
- no exception where 23514 or 42501 was required;
- the reopen recorded as `info`;
- the colleague seeing 2 rows;
- the triggers and functions absent.

Positive Test Design: The tenant has two branches, each with a sales department. The employee and the trainee are placed in Main / Sales and the colleague in Other / Other Sales; a fourth employee has no branch assignment; there is one customer. Positive controls:
- the employee's direct creations persist under the employee and Main / Sales despite a forged owner or filing scope;
- each direct and RPC creation emits exactly one event with the RPC's payload and reaches the customer timeline;
- `app.advance_service_request` still advances and emits once, and an ordinary edit of the request still succeeds;
- a direct walk `requested -> in_progress -> resolved -> closed` succeeds and records exactly three events, as the employee; a no-op status UPDATE and a `resolved_at`-only UPDATE record none;
- the RPC resolves, closes and reopens with a reason, recording exactly one event per move, the reopen a `warning` carrying its reason;
- a session-less `requested` creation keeps its null owner and emits once with a null actor; session-less moves emit once each with a null actor and keep the `resolved_at` they carry.

Negative Test Design:
- **Entry state:** `closed` entry, and `requested` with a resolution time, are refused 23514, signed in and session-less.
- **Archive:** archived entry, and an archiver-named entry, are refused 23514.
- **Placement:** an employee with no primary branch is refused 42501.
- **Owner after creation:** the creator's direct UPDATE moving the owner to a colleague in another branch, or the filing scope to another branch, is refused 23514.
- **Resolution time:** `resolved_at` forged while resolving, and afterwards, is replaced by the server's.
- **Reopen:** a direct reopen with no reason, and the RPC's with a null reason, are refused 23514; after a reasoned RPC reopen, the same direct reopen is still refused.
- **Title:** a blank title at creation and a blanked title afterwards are refused 23514.
- **Capability:** a trainee without CREATE_SERVICE_REQUEST is refused 42501.
- **Tenant:** a row under another tenant is refused 42501 by RLS.
- **Visibility:** the colleague named as owner, and the branch named as filing scope, see 0 rows.
- **Events:** refused creations add no event; a refused reopen adds none.

Non-Empty Population Obligation: One tenant with two branches and two departments, four placed or unplaced users with their roles, one customer, and a rival tenant. Every creation, move and denial is counted by row or event id; no zero-row operation satisfies an assertion.

Mutation Obligation: Out of file, record a surface: the md5 of the guard's, both producers', and both RPCs' text, with the table's trigger definitions. For each mutant:
1. Install it inside test 149's own transaction and prove the surface differs.
2. Run test 149 and record the failing assertions.
3. Prove after the rollback that the surface equals the base.

A mutant whose installation is not proven is a harness error, never a kill.

| Mutant | Change | Expected to fail |
| --- | --- | --- |
| M1 | the entry-state arm removed | 15, 16, 20, 28 |
| M2 | the `resolved_at` conjunct removed | 16, 20 |
| M3 | the archive arm removed | 17, 18, 20 |
| M4 | the archive arm reads only `is_archived` | 18, 20 |
| M5 | the owner derivation removed | 5, 6, 24 |
| M6 | the placement requirement removed | 25 |
| M7 | the created producer dropped | 7, 8, 9, 11, 20, 30, 32 |
| M8 | `app.create_service_request` keeps its own event call | 11, 20 |
| M9 | the UPDATE owner arm removed | 12, 13 |
| M10 | the UPDATE arm checks only `owner_user_id` | 13 |
| M11 | the transition producer dropped | 22, 35, 37, 40, 41, 42, 45, 47 |
| M12 | `app.advance_service_request` keeps its own event call | 22, 42 |
| M13 | the producer does not consume the reason | 37, 41 |
| M14 | the reopen-reason arm removed | 37, 38, 41 |
| M15 | the `resolved_at` stamp removed | 36 |
| M16 | the session-less exemption removed from the UPDATE arm | 46 |
| M17 | the reopen recorded as `info` | 40 |
| M18 | the title arm removed | 43, 44 |
| M19 | the producer fires on a no-op status UPDATE | 35 |
| M20 | `app.advance_service_request` hands no reason | 39, 40, 42 |

M11 and M13 also fail 37: the reason handed by assertion 21's RPC call is then never consumed, and it would otherwise open a later reopen.

Prototype result: base surface `8e9d87415353c1b65b265cca991b047e`. Every installation changed the surface, and every rollback returned it to the base. All twenty were killed, exactly as listed.

Post-Implementation Proof Obligation: All of the following, on the final bytes and through canonical `-Finish`:
- the focused test, a clean reset from the main checkout, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke;
- the out-of-file mutations M1–M20 and the pre-repair causal negative;
- the generated artifacts, the four CI-only guard self-tests, repository consistency and `git diff --check`;
- fresh Primary evidence, parity evidence and the Primary ledger check.

## Implementation Steps

1. **Check** that `supabase/migrations/20261010120000_a_service_request_begins_requested_under_its_creator.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `2da54597b05972dbb12d75c9ce0fc2600a9d610ed86664d859e85dba6ddfed0b`, md5 `351e1ac51761c1b9a62133e381b072a3`, 14009 bytes.
   - Its statements create, each with PUBLIC EXECUTE revoked:
     - `app.guard_service_request_integrity()` with its BEFORE INSERT OR UPDATE trigger;
     - `app.emit_service_request_created()` with its AFTER INSERT trigger;
     - `app.emit_service_request_transition()` with its AFTER UPDATE OF `service_request_status_code` trigger, `WHEN` the status changes.
   - They then replace `app.create_service_request(...)` without its event call, and `app.advance_service_request(...)` with the reason hand-off in place of its event call. A comment block precedes them, stating the authority and SR-1's and SR-2's measurements.
   - If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/149_a_service_request_begins_requested_under_its_creator_test.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `8e69bab0610d83a196644abbf4e3ce53df06f61bcd498e7d56790a27766ca7e4`, `select plan(48);`.
   - Its `-- ATTACK-CLASSES:` line reads `AUTH TENANT DOOR STATE OBSERVABILITY PRIVILEGE INPUT BUSINESS=N/A CONCURRENCY=N/A REPLAY=N/A`, with each `N/A` reason in its header.
   - Then, in `supabase/tests/83_actor_attribution_test.sql`, delete only `service_requests.owner_user_id, ` from assertion 23's expected list, giving SHA-256 `16235efe12063c32dcfe0107c8f6423f4349df8f6d3eed246e7f6b90dd2f4a34`.
   - If a target carries content other than its `3af104b` bytes or its frozen value, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` already contains an `SR-1` row. If not, make these edits and nothing else:
   - **Register:**
     - a 2026-10-10 Slice-35 freshness entry, with the previous one demoted to `Previously:`;
     - after SUB-5, a new row SR-1 (Medium), FIXED by SPEC-257 locally with Primary pending and Cert `🛡`, with the measurements above;
     - a new row SR-2 (Medium), FIXED by SPEC-257 locally with Primary pending and Cert `🛡`, with the measurements above;
     - both rows with Owner `—` and this contract as session;
     - ENTRY-1 gains a dated SPEC-257 entry: `service_requests` closed, the eighth instance, four tables remain, no generic entry rule; its last date becomes 10-10;
     - ARCH-2 gains a dated SPEC-257 entry: `service_requests` refused at entry for every caller, the count falls to ten; its last date becomes 10-10.
   - **Disposition:**
     - a freshness entry, with the previous one demoted;
     - coverage 36 of 78 (15 `AUDITED`, 18 `AUDITED-OPEN`, 3 `PARTIAL`, 42 `NOT-RECORDED`) and the "All 36" line;
     - the `service_requests` row `AUDITED` / `ADVERSARIAL` / SPEC-257 / SR-1, SR-2, ENTRY-1, ARCH-2, with its evidence and its swept non-defects.

   If a target carries content other than its `3af104b` bytes, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 values:
   - a clean local reset from the main checkout; test 149 and the focused tests 07, 08, 32, 54, 83, 111 and 125;
   - pgTAP Pass A, all six HTTP suites, then pgTAP Pass B without reset; smoke and the plan sum;
   - the mutation evidence M1–M20, and the causal negative;
   - the API-contract and map generators;
   - the scope check, `git diff --check` and repository consistency.

   Treat as expected at this boundary only:
   - an undeployed Primary;
   - the pre-deploy repository-consistency drift listed in Consumer Closure;
   - the guard self-test CONTROL failures that drift causes.

   Read a fresh Primary baseline, read-only:
   - the project URL, the full ordered ledger and the absence of the target migration;
   - the function and structural surfaces;
   - `service_requests`' triggers; `app.create_service_request`'s and `app.advance_service_request`'s text md5, security mode and ACL;
   - the tenant, service-request and event counts.

   Record the predicted delta.
5. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 4 and present the Gate-2 package. Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261010120000_a_service_request_begins_requested_under_its_creator`. If it is absent and deployment is separately authorized:
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
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with 464 HTTP assertions last passed on the Step-4 date.
   - Confirm that `supabase/tests` holds 149 files whose literal `plan(N)` values sum to 2745, then set `Suite **149 files / 2745 assertions**`. If either differs, stop.
   - Set Batch 6 coverage to 36 of 78, all thirty-six at `ADVERSARIAL`.
   - Mark SR-1 and SR-2 `DEPLOYED` with Cert `✅`, worded without a date beneath the register's freshness line.
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
     - set `Last Completed` to SPEC-257 / Slice 35;
     - set `Current Module` to Foundation Completion Programme Batch 6 resuming at Slice 36;
     - set `Next capability` to **Foundation Completion Programme — Batch 6 Slice 36**, naming the measured first target, followed by the existing Phase-8 order, closed-chapter and standing-fact sentences unchanged;
     - keep the manifest within 7000 characters;
     - regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate with `scripts/publish_candidate.ps1` and require exact-SHA candidate CI.
   - Promote the same accepted SHA, require main CI, and run `-Certify` for `REMOTE_CERTIFY: READY`.
   - Verify synchronized clean refs.

## Acceptance Criteria

- [x] A direct INSERT by a signed-in CREATE_SERVICE_REQUEST holder persists the request under the creator and the creator's placement, whatever owner or filing scope it supplies; the colleague it named sees 0 rows; an employee with no primary branch is refused 42501.
- [x] After creation, a signed-in UPDATE cannot move the request's owner or filing scope or blank its title (23514), while an ordinary edit succeeds.
- [x] A request cannot be created `closed`, with a resolution time, archived, naming an archiver or with a blank title, signed in or session-less (23514).
- [x] Each successful direct and RPC creation emits exactly one `service_request_created` event, with the RPC's state and payload and the creator (or null) as actor, and reaches the customer timeline; a refused creation emits none.
- [x] Each change of status, direct or through `app.advance_service_request`, emits exactly one canon-26 event with its old and new states, its reason and the session's actor (or null). The reopen is `service_request_reopened` at `warning`. A no-op status UPDATE, a field-only UPDATE and a refused move emit none.
- [x] A signed-in caller's `resolved_at` is `now()` on entering `resolved` and is otherwise kept, whatever the statement supplies; a session-less write keeps the value it carries.
- [x] A closed request cannot be reopened without a reason, directly or through the RPC (23514); the RPC reopens with one; a reason is consumed by the transition it was handed to.
- [x] `app.create_service_request` differs from `3af104b`'s only by the removed event call. `app.advance_service_request` differs only by its event call and the actor lookup that call used being replaced by the reason hand-off; its transition map, permission charge and UPDATE are byte-identical. Both keep their signature, security mode, `search_path` and ACL.
- [x] The held controls stay held: a trainee is refused at the table; a row under another tenant is refused by RLS; session-less `requested` creation keeps its null owner; every edge and its permission are unchanged.
- [x] Mutants M1–M20 are each killed against test 149, with installation and restoration proven. The causal negative is recorded.
- [x] Test 83 assertion 23's expected list drops only `service_requests.owner_user_id`; its query, assertion 22 and every other member are unchanged.
- [x] SR-1 and SR-2 are fixed and deployed in the register. ENTRY-1 and ARCH-2 each record this surface's closure; CHAT-1 and CHAT-2 are unchanged.
- [x] `service_requests` is `AUDITED` / `ADVERSARIAL` in the disposition record, and coverage is 36 of 78. No other surface's row changed.
- [x] The migration, test 149 and test 83 matched their frozen SHA-256 values when applied.
- [x] Primary, the recorded evidence, the manifest (246 migrations; 149 files / 2745 assertions; 464 HTTP assertions), the API contract and `ai-map.json` agree, and the four CI-only guard self-tests and repository consistency pass.
- [x] The manifest names Batch 6 Slice 36 and its measured target as the next capability, with no Active Change Request.
- [x] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [x] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-10-10 — Gate 1 approval and execution started

- **Authority:** the owner's SPEC-257 Gate 1 approval of 2026-10-10 for Draft `8820aee4a723f5f6ae5662d1190cbd6eadac24ac`, contract SHA-256 `7f3479b4b6202394f626440b6bc949a277094afa3bcf286b3a00588d607cb144`, covering SR-1 and SR-2. Verified before acting: HEAD was that commit, the working tree was clean, and the contract file and its committed blob both hash to that value. The frozen prototype files hash to migration `2da54597b05972dbb12d75c9ce0fc2600a9d610ed86664d859e85dba6ddfed0b`, test 149 `8e69bab0610d83a196644abbf4e3ce53df06f61bcd498e7d56790a27766ca7e4` and test 83 `16235efe12063c32dcfe0107c8f6423f4349df8f6d3eed246e7f6b90dd2f4a34`. Approval was committed at `6656cfd`; its pre-commit Gate returned `APPROVAL_EVIDENCE: PASS`.
- **Preconditions:** the migration and test 149 are absent. Test 83 is at its `3af104b` bytes (`868ecc18…`). The register, disposition record, API contract and Primary evidence file are unchanged since `3af104b`.
- **Publication range:** before this commit, `origin/main..HEAD` held 4 commits with 0 merges and was 0 behind.
- **The session-less exemption is not an ordinary caller's path.** The owner asked that this be checked. The guard's UPDATE latitude keys on `auth.uid()` being null. Probed in a rolled-back transaction on the frozen migration:
  - Only `authenticated` holds privileges on `service_requests` (INSERT, SELECT, UPDATE); `anon` and PUBLIC hold none, and an `anon` UPDATE was refused with "permission denied".
  - A token for `authenticated` with no `sub` has a null `auth.uid()` and a null tenant. It saw 0 rows, its UPDATE forging `resolved_at` and reopening a closed request reached 0 rows, and its INSERT was refused by RLS.
  - PostgREST serves only `public` and `graphql_public` (`supabase/config.toml`). Neither holds a `set_config` function, and no migration sets `request.jwt.*`.
  - The probed request stayed `closed`, with no forged resolution time and no reopen event.
- **No Primary write is authorized.** Gate 2 stands before Step 6. Secondary is never contacted.

### 2026-10-10 — Pre-deploy readiness gate (Steps 1–4)

- **Steps 1–3 applied exactly as frozen** in the working tree, uncommitted until after deployment (the pre-commit Gate judges repository consistency on the working tree):
  - migration `2da54597b05972dbb12d75c9ce0fc2600a9d610ed86664d859e85dba6ddfed0b` (md5 `351e1ac51761c1b9a62133e381b072a3`, 14009 bytes, LF);
  - test 149 `8e69bab0610d83a196644abbf4e3ce53df06f61bcd498e7d56790a27766ca7e4`;
  - test 83 `16235efe12063c32dcfe0107c8f6423f4349df8f6d3eed246e7f6b90dd2f4a34`;
  - register `860957837993df0b…` and disposition `96e1e6a8c47dc446…`, each byte-equal to the prototype's.
  - The first write of test 83 was rewritten to CRLF on disk (`5ff72583…`); it was replaced by the frozen LF bytes before any test ran.
- **Causal negative**, before the reset, on the 245-migration database: test 149 failed 31 assertions on the bare schema (5, 6, 7, 8, 9, 12, 13, 15, 16, 17, 18, 20, 24, 25, 28, 30, 31, 32, 33, 34, 35, 36, 37, 38, 40, 41, 43, 44, 45, 47, 48), and exactly SR-2's 11 with the `98f2936` migration (35, 36, 37, 38, 40, 41, 43, 44, 45, 47, 48).
- **Reset from the main checkout** (121 s, exit 0):
  - ledger 246 `a6500a25aeb035493ac37f18cb46fb32`; storage 68 migrations, `bucketid_objname` present;
  - functions `e3d5180863b8482178efde66465a47b4`/323, triggers `a46035c1b6ce74d5d87fa46a40571e16`/309, combined `f56111d6426fb29d91ff6cb41ce1ada2`/3115;
  - the other eight surfaces equal the recorded Primary values.
- **Focused tests:** 149 48/48; 07 2/2; 08 2/2; 32 11/11; 54 6/6; 83 23/23; 111 57/57; 125 31/31.
- **Full order:**
  - pgTAP Pass A 149 files / 2745 PASS (83 s);
  - HTTP 35 + 40 + 85 + 122 + 122 + 60 = 464 passed, 0 failed;
  - Pass B 149 / 2745 PASS (90 s);
  - smoke `ALL CHECKS PASSED (78 tables, … 71/622 catalog, …)`; plan sum 149 / 2745.
- **Mutation:** base surface `8e9d87415353c1b65b265cca991b047e`. M1–M20 were each installed (surface changed), killed exactly as listed in Mutation Obligation, and restored (surface back to base).
- **Generators and hygiene:**
  - the API contract regenerated byte-identical (`d28fb5672ca9c0795a99a74746069c973e1392edcc5e3d2a5a315348138175fd`; 80 RPCs, 80 with HTTP evidence, 8 views, 74 tables); `ai-map.json` is regenerated at Step 7;
  - every touched path is in Write Scope; `git diff --check` is clean;
  - repository consistency reports exactly the 6 expected pre-deploy issues (245 vs 246 migrations, latest, fingerprint, 148 vs 149 files, 2697 vs 2745 assertions, RECOVER-1).
- **Fresh Primary baseline, read-only:**
  - project URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`; ledger 245 `43bf5befaf466ec422d8eaaf5261d250`, latest `20261009120000`, the target absent by version and name;
  - functions `258738c5fea4dd5ff1040cf65997390b`/320, triggers `d07aa82d8ce6e3d8b3adba9310ba657f`/306, combined `902311907ba7e192b285bd43e091ff8d`/3109, every surface equal to the recorded evidence;
  - `service_requests` carries its 7 existing triggers;
  - `app.create_service_request` text md5 `763f11d080a4a200dfdabfdf96e66766` and `app.advance_service_request` `acf9d5567556d6e823bf09ee8b29591c`, both SECURITY INVOKER with ACL `{postgres=X/postgres,authenticated=X/postgres}`; the three new functions are absent;
  - 0 tenants, 0 service requests, 0 events.
- **Predicted delta on Primary:** one ledger row (246, `a6500a25…`); functions 323 and triggers 309, matching the local values; three functions and three triggers added and two function bodies replaced; no other surface and no business row changes.
- **Stop:** Step 5 finds no Gate-2 authorization for the migration's SHA-256. Primary was read only. Secondary was not contacted.

### 2026-10-10 — Human Gate 2: owner authorization

The owner authorized deployment to Primary `vrvtsxexkiiiivlkdxzp` of only `supabase/migrations/20261010120000_a_service_request_begins_requested_under_its_creator.sql`, SHA-256 `2da54597b05972dbb12d75c9ce0fc2600a9d610ed86664d859e85dba6ddfed0b`, MD5 `351e1ac51761c1b9a62133e381b072a3`, through the existing SPEC-257 deployment procedure. The authorization covers exactly that one migration and, if the connector assigns a temporary version, the guarded reconciliation of that one new ledger row under exact MD5 verification. No other Primary change is authorized.

**Conditions:**
- A fresh preflight runs immediately before the write: repository identity, the frozen file hashes, the target project, the complete ledger, the existing object fingerprints and the business counts.
- The transmitted bytes are proven server-side before execution.
- Any material difference from the Gate-2 package aborts the deployment, with no improvised repair and no broadened scope.
- If the connection fails or the outcome is ambiguous, the actual state is established by fresh read-only verification first, and a possibly applied migration is never replayed.
- After the write, the ledger, the migration fingerprint, the functions, the triggers, the grants, the RLS protections and the business counts are verified against the expected state.

After a successful deployment, SPEC-257 continues through its authorized lifecycle to remote certification and synchronization. Secondary `brplkqmbzffpxqgkkdzo` is never contacted.

### 2026-10-10 — Step 6: Primary deployment

**Prewrite recheck, every condition exact:**
- refs: HEAD `2bd67ae6f5ba8bb003ea5ba62d340c6845a54fce`; `origin/main` `3af104b`; this contract's file and its HEAD blob both `b0901798…`;
- the files: migration SHA-256 `2da54597…`, md5 `351e1ac51761c1b9a62133e381b072a3`, 14009 bytes, 0 CR; test 149 `8e69bab0…`, test 83 `16235efe…`, register `86095783…` and disposition `96e1e6a8…` unchanged; `git status` only Write Scope paths;
- project URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`;
- ledger 245, `43bf5befaf466ec422d8eaaf5261d250`, latest `20261009120000`; the target absent by version and name, and no row after `20261009120000`;
- all ten surfaces and combined `902311907ba7e192b285bd43e091ff8d`/3109, equal to the Gate-2 package;
- `service_requests` carried its 7 existing triggers; `app.create_service_request` text md5 `763f11d0…` and `app.advance_service_request` `acf9d556…`, each SECURITY INVOKER with ACL `{postgres=X/postgres,authenticated=X/postgres}`; the three new functions and three new triggers absent;
- 0 tenants, service requests and events.

The first RPC read hashed `pg_get_functiondef` and so differed from the package's text md5; re-read as the package was taken (`md5(prosrc)`), both matched exactly. Nothing was written before that.

**Write:**
- The text to transmit was first proven server-side, read-only, to hash to md5 `351e1ac51761c1b9a62133e381b072a3`, 14009 bytes, 287 LF, 0 CR.
- That text was applied through `apply_migration` as `a_service_request_begins_requested_under_its_creator`. The connector assigned the temporary version `20261010114442`; its single stored statement has md5 `351e1ac5…` and 14009 bytes, equal to the file.
- One guarded CTE UPDATE renamed only that row to `20261010120000`. The guard required 246 rows, exactly one after `20261009120000`, the other 245 hashing to the baseline `43bf5bef…`, the statement md5 to match and no existing target. All five held, and 1 row was renamed.

**Fresh postwrite reads, every value equal to the frozen prediction:**
- **Ledger:** 246, `a6500a25aeb035493ac37f18cb46fb32`, latest `20261010120000`; exactly one row for the migration, under the target version, its statement md5 `351e1ac5…`; the temporary version is gone.
- **Surfaces:** functions `e3d5180863b8482178efde66465a47b4`/323 (the Check L2/P2 expression reads the same); triggers `a46035c1b6ce74d5d87fa46a40571e16`/309; policies `b67d466a…`/125, constraints `cea733ef…`/525, grants `6727f6d8…`/189, columns `448db887…`/1134, views `10bb212a…`/16, indexes `22a4d58c…`/300, status_transitions `db2165c7…`/115 and rls_enabled `c117cbf7…`/79 unchanged; `_combined` `f56111d6426fb29d91ff6cb41ce1ada2`/3115.
- **The five functions:** text md5 `c0c9b1e4…` (guard), `c42a393b…` (created producer), `694bae4e…` (transition producer), `e630aad4…` (create RPC) and `abcec12f…` (advance RPC), each byte-equal to the local stack's, full definitions too. Each is SECURITY INVOKER, owner `postgres`, `search_path=""`; the two RPCs keep ACL `{postgres=X/postgres,authenticated=X/postgres}`, and the three trigger functions hold `{postgres=X/postgres}`.
- **The table:** 10 triggers, all enabled: the 7 before, plus `service_requests_guard_integrity` (BEFORE INSERT OR UPDATE, tgtype 23), `service_requests_emit_created` (AFTER INSERT, 5) and `service_requests_emit_transition` (AFTER UPDATE OF `service_request_status_code`, 17). Row level security is on. Table grants are `authenticated` INSERT, SELECT and UPDATE only.
- **Business rows:** 0 tenants, service requests and events.

**Behaviour on the deployed bytes** is proven locally on the byte-identical functions, because no business data or fixture is written on Primary. Test 149 48/48, the full suite 149/2745 on both passes, the six HTTP suites 464/0, the causal negative and M1–M20 were all recorded on these bytes.

No business-data write and no fixture was made on Primary. Secondary `brplkqmbzffpxqgkkdzo` was not contacted.

### 2026-10-10 — Step 7: evidence and measured state

- **Evidence:** `reports/evidence/primary-ledger-evidence.json` was rewritten from the fresh readings only: 246 migrations, `a6500a25…`, functions `e3d51808…`/323, structural `f56111d6…`/3115, head `2bd67ae`, read at 2026-10-10T11:45:52Z. Its ledger is the Primary ledger read with its own `read_query`; it hashes to `a6500a25aeb035493ac37f18cb46fb32` and equals the repository's 246 migration files. The file is stored LF.
- **Manifest:** `supabase/tests` holds 149 files whose `plan(N)` values sum to 2745. `Live state` reads 246 migrations, latest `20261010120000`, the same hashes and counts, last verified and re-read from Primary 2026-10-10; `Suite **149 files / 2745 assertions**`; and 464 HTTP assertions, last passed 2026-10-10 in the Step-4 run. Batch 6 coverage is 36 of 78, all thirty-six at `ADVERSARIAL`. Tables (78), catalog (71/622) and client RPCs (80) do not move. The manifest measures 6847 characters.
- **Register:** SR-1 and SR-2 are marked DEPLOYED with Cert `✅`, worded without a new date. No other row changed in this step.
- **Generators:** `MASTER_API_CONTRACT.md` regenerates unchanged (SHA-256 `d28fb5672ca9c0795a99a74746069c973e1392edcc5e3d2a5a315348138175fd`). `ai-map.json` was regenerated and stored LF; only its timestamp changed.
- **Checks:** the four CI-only guard self-tests pass: cold-start 34/0, status-contradiction 33/0, primary-ledger 13/0 and future-date 18/0. `check_primary_ledger.ps1` reports `RECOVER-1 LEDGER EVIDENCE: CLEAN`; `check_database_parity_evidence.ps1` reports `DATABASE PARITY: CLEAN` and `PRIMARY PARITY EVIDENCE: CLEAN`, Primary's structure matching local at `f56111d6…`; repository consistency reports `REPOSITORY CONSISTENCY: CLEAN`, the six pre-deploy issues resolved; `git diff --check` is clean.
- **Checkpoint:** the Runtime Checkpoint is DONE, so Step 8's `-Finish` runs in VERIFY mode.

### 2026-10-10 — Post-deploy local certification

Canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` ran on the clean, committed HEAD `5398ac0` in VERIFY mode, with profiles DATABASE and REPOSITORY and nothing else running. It reported `LOCAL_CERTIFY: READY` in 6.4 minutes, and every mandatory verification passed in that run:
- reset; pgTAP Pass A; the declared `verify_journey_branches.ps1` and `verify_lifecycle_branches.ps1`; pgTAP Pass B; smoke;
- `check_database_parity_evidence.ps1`, repository consistency, `git diff --check` and `check_primary_ledger.ps1`.

Before it, on the same committed state, the four CI-only guard self-tests passed (Step 7). The mutation evidence (the causal negative and M1–M20) and the six HTTP suites (464/0) were recorded in Step 4 on the same migration and test bytes, which are unchanged, so they were not repeated.

**Selector after SPEC-257** (`scripts/batch6_select_target.ps1`, 42 surfaces still `NOT-RECORDED`), as Exposure/coverage:
1. `quotation_items` 8/36
2. `totp_enrollments` 8/38
3. `subscription_payment_proofs` 8/48
4. `complaints` 8/48
5. `payment_allocations` 8/60
6. `receipts` 7/20
7. `chart_of_accounts` 7/38
8. `notification_deliveries` 7/42
9. `approval_requests` 7/52
10. `user_branch_assignments` 7/560
11. `user_role_assignments` 7/618
12. `departments` 7/624

Slice 36's measured target is `quotation_items`.

## Verification Notes

### 2026-10-10 — Independent Review of the execution commit `5398ac0`

Reviewed the committed tree against the approved Draft `8820aee`, the Gate-2 authorization and the ten-path Write Scope. The review read the implementation and the live state, not the Execution Log.

1. **Entry by a signed-in creator (criterion 1).** In the committed guard, the INSERT arm derives `owner_user_id`, `owner_branch_id` and `owner_department_id` from `app.current_user_id()` and `app.current_placement()` for every signed-in caller, whatever the statement supplies, and refuses 42501 without a branch. Test 149 asserts the creator's ownership and placement, the named colleague's 0 rows and the 42501. Both `-Finish` pgTAP passes ran it within the whole suite and reported PASS. It passed 48/48 alone in Step 4 on these bytes.
2. **Owner, filing scope and title after creation (criterion 2).** The UPDATE arm refuses a signed-in change to the owner triple (23514); the title rule precedes both arms. Test 149 asserts both refusals, the blank-title UPDATE refusal and an ordinary retitle that lives.
3. **Entry state (criterion 3).** `requested`, a null `resolved_at` and four null archive fields are required of every caller before the session-less return. Test 149 refuses each, signed in and session-less, including a blank title.
4. **One created event (criterion 4).** One AFTER INSERT producer records `service_request_created` with the RPC's state and payload. The create RPC's own call is gone. Test 149 asserts exactly one event per door, its shape, the customer timeline row, the null actor session-less and none for a refused creation.
5. **One transition event (criterion 5).** `service_requests_emit_transition` fires AFTER UPDATE OF `service_request_status_code` only `WHEN` the status changes (tgtype 17 on Primary). It maps each state entered with a `case`, and the reopen at `warning`. The advance RPC's own call is gone. Test 149 asserts the direct walk's event string, exactly one event per RPC move, the reopen's severity and reason, and none for a no-op, a field-only or a refused move.
6. **`resolved_at` (criterion 6).** The guard stamps `now()` on entering `resolved` for a signed-in caller and otherwise keeps the old value. Test 149 asserts the server time over a forged value and the session-less latitude.
7. **The reopen (criterion 7).** The guard refuses a signed-in `closed -> in_progress` without a non-blank `app.transition_reason` (23514); the RPC hands `coalesce(p_reason, '')`, so a null reason is refused there too. The producer clears the setting. Test 149 asserts the direct and RPC refusals, the reasoned reopen and the consumed reason.
8. **The two RPCs (criterion 8).** Diffed against their `3af104b` sources:
   - `202607051500`'s `app.create_service_request` differs only by its removed `record_event` call.
   - `202607050900`'s `app.advance_service_request` differs only by its `record_event` call and the `v_actor` lookup being replaced by the `set_config` hand-off. Its values map, `app.authorize` charge and UPDATE are byte-identical.
   - The new statement also omits the old source's explicit `security invoker` clause. That is PostgreSQL's default, and the function is unchanged by it: Primary read `prosecdef = false` before and after the write.
   - Both keep their signatures, `search_path=""` and ACL `{postgres=X/postgres,authenticated=X/postgres}`, read on Primary.
9. **Held controls (criterion 9).** Test 149 asserts the trainee's table refusal, RLS's refusal under another tenant and the session-less null owner. `status_transitions` reads `db2165c7…`/115 on Primary before and after the write.
10. **Mutation evidence (criterion 10).** M1–M20 and the causal negative were recorded in Step 4 on these migration and test bytes, which are unchanged (`2da54597…`, `8e69bab0…`).
11. **Test 83 (criterion 11).** Against `3af104b`, only assertion 23's expected list changes, dropping `service_requests.owner_user_id`. Its query, assertion 22 and every other member are unchanged.
12. **Register (criterion 12).** SR-1 and SR-2 read FIXED and DEPLOYED with Cert ✅. ENTRY-1 and ARCH-2 each record this surface's closure and nothing else. CHAT-1 and CHAT-2 are unchanged.
13. **Disposition (criterion 13).** `service_requests` is `AUDITED` / `ADVERSARIAL`, and the counts read 36 of 78 (15 `AUDITED`, 18 `AUDITED-OPEN`, 42 `NOT-RECORDED`). No other surface row changed against `3af104b`.
14. **Frozen values (criterion 14).** The committed migration, test 149 and test 83 hash to `2da54597…`, `8e69bab0…` and `16235efe…`.
15. **Agreement (criterion 15).** Primary, the evidence and the manifest agree: 246 migrations, `a6500a25…`, functions `e3d51808…`/323, structural `f56111d6…`/3115, 149 files / 2745 assertions, 464 HTTP assertions. The API contract matches its generator, `ai-map.json` is LF, and the four guard self-tests and repository consistency pass.
16. **Next capability (criterion 16).** The Complete commit names Batch 6 Slice 36 and `quotation_items` (8/36) and clears the Active Change Request.
17. **Primary and Secondary (criterion 17).** Primary's ledger holds exactly one row for the migration, its statement md5 `351e1ac5…` equal to the authorized file, after one guarded rename. It holds 0 tenants, service requests and events before and after. Secondary was never contacted.
18. **Scope (criterion 18).** `3af104b..HEAD` changes only Write Scope paths, and `MASTER_API_CONTRACT.md` regenerates unchanged.

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

- **EARN IT.**
  - SR-1 was reproduced by an employee proven first to hold the capability, at creation and by a later owner move. SR-2 was reproduced by the same employee, who also holds RESOLVE_SERVICE_REQUEST, on both doors.
  - Test 149 fails 31 assertions for their intended reasons on the unrepaired schema, and exactly SR-2's 11 with SR-1's repair alone.
  - Each arm of the guard, both producers and both RPC hand-offs is pinned by an installed, killed mutant.
- **WORTH IT.**
  - A capability holder could create customer work already closed or archived, in a narrative nobody authorized, or in a colleague's name, which the colleague's branch could then read.
  - The same holder could then live the request's whole life with no event canon 26 requires, date its resolution at will, and reopen it without the reason canon 27 requires; the RPC itself reopened without one.
  - SR-2 was first recorded Low and left open. It is repaired here because each part breaks a stated canon rule on a surface this contract already changes, at the cost of a few guard lines and one producer.
- **SIMPLIFY IT WITHOUT WEAKENING.**
  - One guard and two producers, in the shapes SPEC-220, SPEC-216 and SPEC-237 already proved, plus each RPC's own event call replaced.
  - Nothing is added beyond them: no table, column, grant, policy, permission, event type, state transition or shared framework.
  - Every legal, authorized table-door edge still works, and is now recorded.
- **Owner authorization (2026-10-10).** The owner's directive resumes Batch 6 at Slice 35 through the existing lifecycle. `CR_LIFECYCLE.md` makes `Draft -> Approved` a human act, so this Draft stops at Gate 1. Approval, when given, still does not authorize any Primary write; Gate 2 is separate. A later owner directive asked that SR-2 be judged on its evidence rather than its recorded severity; on that evidence, this Draft absorbs it.
- **Deliberately not changed:**
  - `resolved_at` on reopen, which the sanctioned writer keeps;
  - customer–booking coherence;
  - canon 24, 26, 27, 28 and 29;
  - CHAT-1 and CHAT-2;
  - the other ENTRY-1 and ARCH-2 tables;
  - the n8n workflow, PH8-10 and Phase 8;
  - the registered worktrees `owt/p2` and `C:\w234`.
