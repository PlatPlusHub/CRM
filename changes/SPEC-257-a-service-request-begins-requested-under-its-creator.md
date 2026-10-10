# Change Request — SPEC-257

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Foundation Completion Programme Batch 6 Slice 35: give `public.service_requests` a truthful disposition and close **SR-1**.

The surface is canon 24's Service Request: operational work a customer asks for after booking, linked to the customer and optionally to the booking or booking item it concerns. `authenticated` holds table-level INSERT, SELECT and UPDATE, and both RPCs, `app.create_service_request` and `app.advance_service_request`, are SECURITY INVOKER through that same grant, so PostgREST serves the table beside them.

After this change one invariant holds on both doors: **a service request begins `requested`, unresolved and unarchived, owned and filed by whoever opens it, with exactly one `service_request_created` event; and no signed-in UPDATE moves its owner or filing scope afterwards.**

Record the surface `AUDITED-OPEN` and close this surface's instances of **ENTRY-1** and **ARCH-2**. Record **SR-2**, the lifecycle evidence the table door loses after creation, as OPEN and do not repair it.

This contract does not touch `app.advance_service_request`, any UPDATE other than one moving the owner or filing scope, canon 26, 27, 28 or 29, any other surface, n8n or any Phase-8 work.

## Business Reason

### Selection
`scripts/batch6_select_target.ps1` at `3af104b` ranks `service_requests` first: `NOT-RECORDED`, Exposure 8, coverage 34, 7 test files, 2 direct writes, no SECURITY DEFINER function, 2 RPCs and 1 state signal. The runner-up is `quotation_items` at 8/36. The 7 test files only name the table in catalog sweeps and fixtures; no pgTAP file calls either RPC.

### Authority
- **Canon 26 (Service Request State Machine):** the states are `requested`, `in_progress`, `awaiting_customer`, `awaiting_supplier`, `resolved` and `closed`; the normal flow starts at `requested`; `service_request_created` is a required event.
- **Canon 27:** `service_request_created` (info); `service_request_reopened` requires a reopen reason and an authorized actor.
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

### The repair
One migration, in SPEC-220's shape:
- `app.guard_service_request_integrity()`, SECURITY INVOKER with an empty `search_path` and PUBLIC EXECUTE revoked, is attached as the row-level BEFORE INSERT OR UPDATE trigger `service_requests_guard_integrity`, the shape of `app.guard_document_integrity` (SPEC-216).
  - On UPDATE, a signed-in caller cannot change `owner_user_id`, `owner_branch_id` or `owner_department_id` (23514): what no sanctioned writer ever changes, the table door cannot change either. Every other UPDATE passes through untouched, and session-less platform writes are exempt.
  - For every caller it requires `requested` with a null `resolved_at`, and no archive field (23514).
  - For a signed-in caller it resolves `app.current_user_id()` and `app.current_placement()`, refuses with 42501 when there is no actor or branch, and derives `owner_user_id`, `owner_branch_id` and `owner_department_id`.
  - Session-less platform writes keep their nullable owner.
- `app.emit_service_request_created()`, with the same security, is attached as the row-level AFTER INSERT trigger `service_requests_emit_created`.
  - It calls `app.record_event` with the RPC's exact event type, entity, state and payload keys (`customer_id`, `service_request_type_code`).
  - The actor is the session's user, or null.
- `app.create_service_request` is replaced by its complete current definition, minus only its `app.record_event` call. Its signature, SECURITY INVOKER, `search_path` and `authenticated` EXECUTE are unchanged.

No table, column, grant, policy, permission, event type or catalog value is added.

### Rejected
- **Widening `service_requests_enforce_archive_authority` to INSERT:** it would authorize and stamp an archive at creation, which no RPC does. Refusing at entry is what `documents` chose for ARCH-2 (SPEC-216).
- **An entry-state row in `app.status_transitions`:** ENTRY-1 weighed and declined promotion three times, because it changes INSERT behaviour on surfaces no slice has read.
- **Revoking INSERT from `authenticated`:** the RPC is SECURITY INVOKER and inserts through that grant. Making it a definer would move its RLS and capability semantics, which is a larger change than the defect.
- **Charging a permission for reassignment:** canon 28 defines none for service requests, and choosing one would be policy. Refusing the move is the fail-closed reading of the sole sanctioned writer, and canon 28's owner-ratified note 1 already lets a department colleague continue a request when its owner is absent, without reassignment. A reassignment act, if canon ever defines one, belongs to SR-2's design.
- **A second guard for the owner rule:** the creation guard already owns the owner fields; its UPDATE arm is three lines.
- **Repairing the lifecycle evidence here:** see SR-2.

### Held, recorded so a later slice does not rediscover it
- **The UPDATE door's edges:** `app.status_transitions` charges RESOLVE_SERVICE_REQUEST on every status change. CREATE_SERVICE_REQUEST and RESOLVE_SERVICE_REQUEST are held by exactly the same roles (owner, ceo, branch_manager, department_manager, senior_employee, employee), so `guard_write_capability`'s either-permission rule on UPDATE escalates nobody.
- **Capability:** a trainee without CREATE_SERVICE_REQUEST is refused at the table (42501).
- **Tenant:** a row under another tenant is refused by RLS. A foreign customer, booking or item is refused by the tenant-qualified foreign keys. There is no DELETE grant.
- **Customer–booking coherence:** both doors accept a request under one customer naming another customer's booking in the same tenant. No canon rule states coherence, and no surface in the repository enforces it, so it is recorded here and not invented.

### SR-2 (Low), recorded and not repaired here
After creation, the table door keeps no lifecycle evidence. This is CHAT-2's shape on this surface. Measured at `3af104b` by the same employee, and re-measured on the repaired prototype:
- A legal direct UPDATE moved a request `requested -> in_progress -> resolved -> closed` with no transition event, and with `resolved_at` forged to 2001-01-01.
- A later UPDATE wrote `resolved_at` 2019-05-05 with no status change.
- `app.advance_service_request` reopened `closed -> in_progress` with a null reason, although canon 27 requires one.
- The table accepts a blank title, which the RPC refuses.

Every actor here already holds the authority the RPC charges, and every edge is the canon-26 graph's: `requested -> closed` is refused, and archiving, the archiver and the archive reason each still cost ARCHIVE_RECORD on UPDATE (re-measured: all three refused to the employee; a branch manager's archive was stamped by the server). What is lost is evidence and normalization, not authority. The trigger for repairing it is a service-request lifecycle-authority design that keeps `app.advance_service_request(p_reason)` semantics on both doors, as CHAT-2 awaits for conversations.

## Risks

- **Changed INSERT semantics.**
  - A signed-in direct INSERT now gets the creator's own owner and placement, whatever it supplies.
  - A non-`requested`, resolved or archived entry is refused for every caller.
  - Nothing legitimate creates either today: the only session-less writer is test 111's `requested` fixture, there is no seed, and both HTTP suites that create requests use the RPC.
- **Signed-in reassignment stops.** A CREATE or RESOLVE holder can no longer move a request's owner or filing scope at the table. No RPC or HTTP suite does it, and no canon act defines it; department visibility covers an absent owner. The platform's session-less path keeps it.
- **The event moves.** Each successful INSERT emits `service_request_created` once, from the trigger, and the RPC no longer emits it itself. A refused INSERT emits nothing. Test 149 pins exactly one event per door.
- **The attribution inventory.** Test 83 assertion 23 pins the users-FK columns that no BEFORE trigger derives. The new guard derives `service_requests.owner_user_id`, so exactly that member leaves the expected list. Its query, assertion 22 and every other member stay unchanged. This is the consumer whose omission cancelled SPEC-219.
- **Primary deployment** adds two functions and two triggers and replaces one function body, and nothing else. It requires separate exact-byte owner authorization (Gate 2); approving this contract does not authorize it. Primary holds no service requests.
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
- `reports/master/MASTER_GAP_REGISTER.md` (ENTRY-1, ARCH-2, CHAT-1, CHAT-2); `reports/master/MASTER_SURFACE_DISPOSITION.md`; `reports/master/MASTER_EXECUTION_PLAN.md` Batch 6 method and EC-1…EC-11
- `supabase/migrations/202607051500_branch_filed_write_paths.sql`; `supabase/migrations/20260924170000_conversation_creation_parity.sql`
- Current local `app.create_service_request`, `app.advance_service_request`, `app.record_event`, `app.current_placement`, `app.guard_write_capability`, `app.enforce_status_transition`, `app.enforce_archive_authority`
- Tests 83 (assertion 23), 111 and 125

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

- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A signed-in INSERT is `requested`, unresolved and unarchived, owned and filed by its creator | `scope_isolation` RLS; `app.advance_service_request`; `app.status_transitions`; `app.enforce_archive_authority` | WRITE | The prototype was a scratch worktree at `3af104b`, with the migration applied with its ledger row on a stack reset from the main checkout. Migration SHA-256 `67d8c76e5b7aecaa68aa5a2733113b22dfbbe2d7dfd9bc22938ca7a7d3d66198`, md5 `64c524af293b90636980f4459b0d4968`, 7957 bytes, 167 LF lines, ASCII. A forged owner and a forged filing scope were replaced by the creator's own; the colleague in the other branch then saw 0 rows. After creation, a signed-in move of the owner or filing scope was refused 23514, while an ordinary edit succeeded. Closed, resolved, archived and archiver-named entries were refused 23514. An employee with no primary branch was refused 42501. The UPDATE door is unchanged: `app.advance_service_request` still advances and emits once. |
| `service_request_created` moves from the RPC body to an AFTER INSERT producer | `public.events`; `app.customer_timeline`; `verify_journey_branches.ps1` and `verify_lifecycle_branches.ps1` (RPC creation) | WRITE | Before: a direct creation emitted 0 events and the RPC emitted 1. Prototype: each direct and RPC creation emitted exactly 1, with the RPC's payload and the creator as actor, and reached the customer timeline. A refused creation emitted none. Both HTTP suites pass unchanged (85/0 and 122/0). |
| Session-less INSERT | test 111's fixture; future platform writers | VERIFY | The entry state binds a session-less write too (a session-less `closed` creation is refused 23514). A session-less `requested` creation keeps its null owner and emits once with a null actor. Test 111 passes unchanged (57/57). |
| Creation ownership becomes trigger-derived and fixed against signed-in UPDATEs | `83_actor_attribution_test.sql` assertion 23 | WRITE | Its query lists users-FK columns that `authenticated` can write and no BEFORE trigger derives. The guard removes `service_requests.owner_user_id` from that measured set, and on the prototype only assertion 23 failed until exactly that member was removed. Test 83: SHA-256 `868ecc18194cd7e7e12add2f60eb336cee342a2b411ddc08e789892ce568bc62`, 21202 bytes → `16235efe12063c32dcfe0107c8f6423f4349df8f6d3eed246e7f6b90dd2f4a34`, 21170 bytes, a one-line diff deleting `service_requests.owner_user_id, `. Then 23/23. |
| Test 149 | `supabase/tests` | WRITE | SHA-256 `734daa1933918d4cec6c3cd04e6d118c49e3a941e011a0fb722d97cf101dae2d`, `plan(34)`, 16727 bytes, LF, ASCII: 34/34 on the prototype. On the unrepaired schema 20 fail, each for its intended reason: 5, 6, 7, 8, 9, 12, 13, 15, 16, 17, 18, 20, 24, 25, 28, 30, 31, 32, 33, 34. |
| The generated API contract | `MASTER_API_CONTRACT.md` | WRITE | The canonical generator against the prototype reports 80 RPC endpoints (80 with HTTP evidence), 8 views and 74 tables. It is byte-identical to the committed contract (SHA-256 `d28fb5672ca9c0795a99a74746069c973e1392edcc5e3d2a5a315348138175fd`): no grant, table or client RPC moves. Step 7 regenerates it, and it stays unchanged. |
| Suite, HTTP and smoke | full pgTAP; the six HTTP suites; `scripts/verify_database.sql` | VERIFY | On the prototype, in `-Finish`'s order on a main-checkout reset: pgTAP Pass A 149 files / 2731 assertions PASS (2697 + 34); HTTP 35 + 40 + 85 + 122 + 122 + 60 = 464 passed, 0 failed; Pass B 149 / 2731 PASS; smoke `ALL CHECKS PASSED (78 tables, … 71/622 catalog, …)`; plan sum 149 / 2731. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | The local reset equalled the recorded Primary values (245 migrations, `43bf5befaf466ec422d8eaaf5261d250`; functions `258738c5fea4dd5ff1040cf65997390b`/320; triggers `d07aa82d8ce6e3d8b3adba9310ba657f`/306; combined `902311907ba7e192b285bd43e091ff8d`/3109). With the migration, functions became `cc0dbed5b3bf2a2dc373a083ed0305f0`/322, triggers `2b835f0a0297ee9054d4f1816539bdd1`/308 and combined `73996e60e19e163794a314c8b26777ee`/3113. Policies, constraints, grants, columns, views, indexes, status transitions and RLS are unchanged. The 246-file ledger fingerprint is `a6500a25aeb035493ac37f18cb46fb32`. |
| Measured state that moves | manifest (`Live state`, suite figure, coverage, Last Completed, Current Module, Next capability); `primary-ledger-evidence.json`; `ai-map.json` | WRITE | 245 → 246 migrations, latest `20261010120000`; 148 → 149 files and 2697 → 2731 assertions; coverage 35 → 36 of 78. HTTP (464), tables (78), catalog (71/622), views (8) and client RPCs (80) do not move. Primary values are written only from fresh post-deploy readings. |
| SR-1 fixed, SR-2 recorded, ENTRY-1 and ARCH-2 annotated; the surface `AUDITED-OPEN` | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24, 25 | WRITE | Test 149's `-- ATTACK-CLASSES:` line and negative assertions satisfy Check 24 for `service_requests`. SR-1's and SR-2's Owner field is `—`, so Check 25 reads no owner decision. The disposition row names this contract as its session. On the prototype, Checks 21, 24 and 25 pass. Check 22 passes once this file exists. |
| CI-only guard self-tests and repository consistency | `scripts/test_*_guard.ps1` (four); `scripts/check_repository_consistency.ps1` | VERIFY | On the prototype, future-date (18/0) and status-contradiction (33/0) pass. Primary-ledger (11 passed, 2 failed) and cold-start (25 passed, 9 failed) fail ONLY their CONTROL and restore cases, which require an untouched copy of the repository to be CLEAN; every mutation case passes. Repository consistency reports exactly the pre-deploy measured-state drift: `manifest says 245 migrations, repository holds 246`; latest `20261009120000` vs `20261010120000`; ledger fingerprint `43bf5bef…` vs `a6500a25…`; `148 test files` vs 149; `2697 assertions` vs 2731; RECOVER-1 ledger evidence. These are not waived: Step 7 makes them true, and Step 8 requires them green. |

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

Existing Mechanism: `app.enforce_status_transition` fires on UPDATE only. `app.enforce_archive_authority` fires on UPDATE only. `app.guard_write_capability` charges CREATE_SERVICE_REQUEST (or RESOLVE_SERVICE_REQUEST on UPDATE) but checks no entry state, creator, owner move or event, and RLS judges scope against caller-supplied owner fields, so a creator's WITH CHECK passes for a move it makes itself. Only the RPC supplies the correct creation values and the event. This contract reuses `app.record_event`, `app.current_placement()`, `app.current_user_id()`, the capability trigger and the existing RLS and foreign keys. No shared entry or event framework is earned (ENTRY-1 declined promotion three times).

Added Property: A successful INSERT through either door begins `requested`, unresolved and unarchived, under the actual creator and placement for a signed-in caller, and emits exactly one `service_request_created` with the RPC's payload. A refused INSERT emits none. Afterwards no signed-in UPDATE moves the owner or filing scope.

Causal Negative: These are the pre-repair measurements in Business Reason, at `3af104b`:
- direct creation `closed` with `resolved_at` 2020-01-01;
- direct creation archived with a colleague as `archived_by` and a forged reason;
- direct creation naming a colleague in another branch as owner, readable by that colleague;
- zero `service_request_created` events for every direct creation;
- after a legitimate creation, a direct UPDATE moving the owner or filing scope to another branch, which that branch then read.

On the unrepaired schema, test 149 fails assertions 5, 6, 7, 8, 9, 12, 13, 15, 16, 17, 18, 20, 24, 25, 28, 30, 31, 32, 33 and 34, each for its intended reason. The causes are:
- the forged owner or filing kept, at creation or by a later UPDATE;
- no event;
- no exception where 23514 or 42501 was required;
- the colleague seeing 2 rows;
- the triggers and functions absent.

Positive Test Design: The tenant has two branches, each with a sales department. The employee and the trainee are placed in Main / Sales and the colleague in Other / Other Sales; a fourth employee has no branch assignment; there is one customer. Positive controls:
- the employee's direct creations persist under the employee and Main / Sales despite a forged owner or filing scope;
- each direct and RPC creation emits exactly one event with the RPC's payload and reaches the customer timeline;
- `app.advance_service_request` still advances and emits once, and an ordinary edit of the request still succeeds;
- a session-less `requested` creation keeps its null owner and emits once with a null actor.

Negative Test Design:
- **Entry state:** `closed` entry, and `requested` with a resolution time, are refused 23514, signed in and session-less.
- **Archive:** archived entry, and an archiver-named entry, are refused 23514.
- **Placement:** an employee with no primary branch is refused 42501.
- **Owner after creation:** the creator's direct UPDATE moving the owner to a colleague in another branch, or the filing scope to another branch, is refused 23514.
- **Capability:** a trainee without CREATE_SERVICE_REQUEST is refused 42501.
- **Tenant:** a row under another tenant is refused 42501 by RLS.
- **Visibility:** the colleague named as owner, and the branch named as filing scope, see 0 rows.
- **Events:** refused creations add no event.

Non-Empty Population Obligation: One tenant with two branches and two departments, four placed or unplaced users with their roles, one customer, and a rival tenant. Every creation and denial is counted by row or event id; no zero-row operation satisfies an assertion.

Mutation Obligation: Out of file, record a surface: the md5 of the guard's, the producer's and `app.create_service_request`'s text with the table's trigger names. For each mutant:
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
| M7 | the event producer dropped | 7, 8, 9, 11, 20, 30, 32 |
| M8 | the RPC keeps its own event call | 11, 20 |
| M9 | the UPDATE owner arm removed | 12, 13 |
| M10 | the UPDATE arm checks only `owner_user_id` | 13 |

Prototype result: base surface `bf50c715b0de97e0ce75c8a0c3d613bc`. Every installation changed the surface, and every rollback returned it to the base. All ten were killed, exactly as listed.

Post-Implementation Proof Obligation: All of the following, on the final bytes and through canonical `-Finish`:
- the focused test, a clean reset from the main checkout, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke;
- the out-of-file mutations M1–M10 and the pre-repair causal negative;
- the generated artifacts, the four CI-only guard self-tests, repository consistency and `git diff --check`;
- fresh Primary evidence, parity evidence and the Primary ledger check.

## Implementation Steps

1. **Check** that `supabase/migrations/20261010120000_a_service_request_begins_requested_under_its_creator.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `67d8c76e5b7aecaa68aa5a2733113b22dfbbe2d7dfd9bc22938ca7a7d3d66198`, md5 `64c524af293b90636980f4459b0d4968`, 7957 bytes.
   - Its statements create `app.guard_service_request_integrity()` with its BEFORE INSERT OR UPDATE trigger, and `app.emit_service_request_created()` with its AFTER INSERT trigger, each with PUBLIC EXECUTE revoked. They then replace `app.create_service_request(...)` without its event call. A comment block precedes them, stating the authority and SR-1's measurements.
   - If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/149_a_service_request_begins_requested_under_its_creator_test.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `734daa1933918d4cec6c3cd04e6d118c49e3a941e011a0fb722d97cf101dae2d`, `select plan(34);`.
   - Its `-- ATTACK-CLASSES:` line reads `AUTH TENANT DOOR STATE OBSERVABILITY PRIVILEGE INPUT=N/A BUSINESS=N/A CONCURRENCY=N/A REPLAY=N/A`, with each `N/A` reason in its header.
   - Then, in `supabase/tests/83_actor_attribution_test.sql`, delete only `service_requests.owner_user_id, ` from assertion 23's expected list, giving SHA-256 `16235efe12063c32dcfe0107c8f6423f4349df8f6d3eed246e7f6b90dd2f4a34`.
   - If a target carries content other than its `3af104b` bytes or its frozen value, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` already contains an `SR-1` row. If not, make these edits and nothing else:
   - **Register:**
     - a 2026-10-10 Slice-35 freshness entry, with the previous one demoted to `Previously:`;
     - after SUB-5, a new row SR-1 (Medium), FIXED by SPEC-257 locally with Primary pending and Cert `🛡`, with the measurements above;
     - a new row SR-2 (Low, OPEN, Cert `📋`), with the evidence above;
     - both rows with Owner `—` and this contract as session;
     - ENTRY-1 gains a dated SPEC-257 entry: `service_requests` closed, the eighth instance, four tables remain, no generic entry rule; its last date becomes 10-10;
     - ARCH-2 gains a dated SPEC-257 entry: `service_requests` refused at entry for every caller, the count falls to ten; its last date becomes 10-10.
   - **Disposition:**
     - a freshness entry, with the previous one demoted;
     - coverage 36 of 78 (14 `AUDITED`, 19 `AUDITED-OPEN`, 3 `PARTIAL`, 42 `NOT-RECORDED`) and the "All 36" line;
     - the `service_requests` row `AUDITED-OPEN` / `ADVERSARIAL` / SPEC-257 / SR-1, SR-2, ENTRY-1, ARCH-2, with its evidence, its swept non-defects and SR-2 open.

   If a target carries content other than its `3af104b` bytes, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 values:
   - a clean local reset from the main checkout; test 149 and the focused tests 83, 111 and 125;
   - pgTAP Pass A, all six HTTP suites, then pgTAP Pass B without reset; smoke and the plan sum;
   - the mutation evidence M1–M10, and the causal negative;
   - the API-contract and map generators;
   - the scope check, `git diff --check` and repository consistency.

   Treat as expected at this boundary only:
   - an undeployed Primary;
   - the pre-deploy repository-consistency drift listed in Consumer Closure;
   - the guard self-test CONTROL failures that drift causes.

   Read a fresh Primary baseline, read-only:
   - the project URL, the full ordered ledger and the absence of the target migration;
   - the function and structural surfaces;
   - `service_requests`' triggers; `app.create_service_request`'s text md5, security mode and ACL;
   - the tenant, service-request and event counts.

   Record the predicted delta.
5. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 4 and present the Gate-2 package. Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261010120000_a_service_request_begins_requested_under_its_creator`. If it is absent and deployment is separately authorized:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts, the table's triggers and the RPC's md5.
   - On an exact match, prove the transmitted text's md5 server-side, then apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires:
     - exactly one new row;
     - its stored statement md5 equal to the file's;
     - no existing target version.
   - Read fresh:
     - the ledger, the function surface and all ten structural surfaces;
     - the table's triggers;
     - the three functions' definitions, security modes and ACLs;
     - the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with 464 HTTP assertions last passed on the Step-4 date.
   - Confirm that `supabase/tests` holds 149 files whose literal `plan(N)` values sum to 2731, then set `Suite **149 files / 2731 assertions**`. If either differs, stop.
   - Set Batch 6 coverage to 36 of 78, all thirty-six at `ADVERSARIAL`.
   - Mark SR-1 `DEPLOYED` with Cert `✅`, worded without a date beneath the register's freshness line.
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

- [ ] A direct INSERT by a signed-in CREATE_SERVICE_REQUEST holder persists the request under the creator and the creator's placement, whatever owner or filing scope it supplies; the colleague it named sees 0 rows; an employee with no primary branch is refused 42501.
- [ ] After creation, a signed-in UPDATE cannot move the request's owner or filing scope (23514), while an ordinary edit succeeds.
- [ ] A request cannot be created `closed`, with a resolution time, archived or naming an archiver, signed in or session-less (23514).
- [ ] Each successful direct and RPC creation emits exactly one `service_request_created` event, with the RPC's state and payload and the creator (or null) as actor, and reaches the customer timeline; a refused creation emits none.
- [ ] `app.create_service_request` differs from `3af104b`'s only by the removed event call, with signature, security mode, `search_path` and ACL unchanged. `app.advance_service_request` is byte-identical and still advances and emits once.
- [ ] The held controls stay held: a trainee is refused at the table; a row under another tenant is refused by RLS; session-less `requested` creation keeps its null owner.
- [ ] Mutants M1–M10 are each killed against test 149, with installation and restoration proven. The causal negative is recorded.
- [ ] Test 83 assertion 23's expected list drops only `service_requests.owner_user_id`; its query, assertion 22 and every other member are unchanged.
- [ ] SR-1 is fixed and deployed in the register. SR-2 is recorded OPEN, Low, and unrepaired. ENTRY-1 and ARCH-2 each record this surface's closure; CHAT-1 and CHAT-2 are unchanged.
- [ ] `service_requests` is `AUDITED-OPEN` / `ADVERSARIAL` in the disposition record, and coverage is 36 of 78. No other surface's row changed.
- [ ] The migration, test 149 and test 83 matched their frozen SHA-256 values when applied.
- [ ] Primary, the recorded evidence, the manifest (246 migrations; 149 files / 2731 assertions; 464 HTTP assertions), the API contract and `ai-map.json` agree, and the four CI-only guard self-tests and repository consistency pass.
- [ ] The manifest names Batch 6 Slice 36 and its measured target as the next capability, with no Active Change Request.
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

None.

## Verification Notes

None.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created or deleted.
- [ ] No section was added, removed or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

- **EARN IT.**
  - SR-1 was reproduced by an employee proven first to hold the capability, at creation and by a later owner move, and by test 149 failing 20 assertions for their intended reasons on the unrepaired schema.
  - Each arm of the guard and the producer is pinned by an installed, killed mutant.
- **WORTH IT.** A capability holder could create customer work already closed or archived, in a narrative nobody authorized, or in a colleague's name, which the colleague's branch could then read. None of it left the event canon 26 requires.
- **SIMPLIFY IT WITHOUT WEAKENING.** One guard and one producer, in the shapes SPEC-220 and SPEC-216 already proved, plus one call removed from the RPC. Nothing is added beyond them: no table, column, grant, policy, permission, event type or shared framework. The UPDATE door, its permission charges and `app.advance_service_request` are untouched.
- **Owner authorization (2026-10-10).** The owner's directive resumes Batch 6 at Slice 35 through the existing lifecycle. `CR_LIFECYCLE.md` makes `Draft -> Approved` a human act, so this Draft stops at Gate 1. Approval, when given, still does not authorize any Primary write; Gate 2 is separate.
- **Deliberately not changed:**
  - SR-2: the direct lifecycle UPDATE's events, `resolved_at`, the reopen reason and the blank title;
  - customer–booking coherence;
  - canon 24, 26, 27, 28 and 29;
  - CHAT-1 and CHAT-2;
  - the other ENTRY-1 and ARCH-2 tables;
  - the n8n workflow, PH8-10 and Phase 8;
  - the registered worktrees `owt/p2` and `C:\w234`.
