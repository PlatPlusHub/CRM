# Change Request — SPEC-219

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make successful conversation creation preserve the same initial state, creator scope and start event through the table and RPC doors.

## Business Reason

Batch 6 Slice 19 selected `conversations` live (Exposure 11, coverage 66; `payments` runner-up at 11/84; 19/77 previously dispositioned). An authenticated employee holding SEND_MESSAGE inserted a conversation already `closed`, with an old `started_at`, null `closed_at` and no event; the RPC creates only `open` conversations and emits `conversation_started`. A direct `open` insert naming a colleague as owner persisted that false responsibility and still emitted no event. `app.customer_timeline` showed zero starts for the direct conversation and one for the RPC. The owning-user and branch fields drive RLS and child-message visibility. A rolled-back cross-department probe showed that the forged owner could read the row through assigned-user RLS (one row), while the creation-guard prototype derived the actual owner and reduced that colleague's visible count to zero. This is the `conversations` instance of ENTRY-1 plus CHAT-1, a reproduced creation-door provenance and observability gap.

## Risks

- The creation guard changes authenticated direct INSERT semantics: it refuses non-`open` or pre-closed entry, derives creator and filing scope from the session, and must preserve legitimate direct and RPC writes. Session-less platform/fixture writes must retain their nullable pre-identification model.
- Moving `conversation_started` emission from the RPC to an AFTER INSERT trigger must produce one event on each successful door and none on refused writes. Existing lifecycle and message events, reason semantics, grants, RLS, catalogs, subscription controls and duplicate prevention must remain intact.
- Primary deployment is a production schema change and requires separate owner authorization for exact migration and permanent-test bytes after local proof.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-219-conversation-creation-parity.md`
- `supabase/migrations/20260924170000_conversation_creation_parity.sql`
- `supabase/tests/125_conversation_creation_parity_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607050900_customer_service_write_paths.sql`
- `supabase/migrations/202607051500_branch_filed_write_paths.sql`
- `supabase/migrations/202607052700_lifecycle_transition_enforcement.sql`
- `supabase/tests/67_care_capability_and_message_integrity_test.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `reports/architecture-decision-records.md`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/26_state_machines.md` (Conversation State Machine); `_ORVION_CANONICAL/27_event_catalog.md` (Conversation Events); `_ORVION_CANONICAL/28_permissions_matrix.md` (conversation permissions and read scope); `_ORVION_CANONICAL/31_schema_draft.md` (`conversations`)
- Current local `app.start_conversation`, `app.record_event`, `app.current_placement` and `app.guard_write_capability`; `supabase/migrations/202607051500_branch_filed_write_paths.sql`
- `reports/master/MASTER_GAP_REGISTER.md` (ENTRY-1, CONV-3); `reports/master/MASTER_SURFACE_DISPOSITION.md` (`conversations`)
- `reports/master/MASTER_INTEGRATION_CATALOG.md` §0; `reports/evidence/primary-ledger-evidence.json`

## Runtime Checkpoint

Resume Step: 1
Blocker: CR_APPROVAL_REQUIRED
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
| Authenticated conversation entry is `open` with null `closed_at` | Conversation state machine; `app.send_conversation_message`; `conversation_messages_guard_parent_state` | VERIFY | Direct closed entry persisted without a closure event/time; RPC entered `open`. The message door reads the parent status. Preserve existing legal UPDATE transitions; this CR changes INSERT only. |
| Creation owner, owner branch/department and initial current branch/department derive from the actual session and `app.current_placement()` | `scope_isolation` RLS; child-message scope; department visibility | VERIFY | Direct INSERT naming a colleague in another department persisted the colleague ID and made the row visible to that colleague through assigned-user RLS. The RPC derives actual caller and placement. Rolled-back prototype overwrote the false owner with the employee's actual ID, and the other-department colleague then saw zero rows; disabling the guard positively restored false ownership. |
| Start event moves from RPC body to successful table INSERT | `public.events`; `app.customer_timeline`; HTTP `start_conversation` | VERIFY | Before: direct start 0 timeline entries, RPC 1. Prototype: direct and RPC each persisted one row with one event. Disabling the emitter produced zero for a successful direct start; restoring the old RPC event block produced two for one RPC start. |
| Session-less conversation INSERT | existing fixtures and future integration model (CONV-3) | VERIFY | Prototype inserted a session-less `open` row with null owner and obtained one event with null actor. The guard enforces initial state and null closure time for every insert, while skipping only session-derived owner/scope for session-less writes; this CR does not create the deferred inbound integration door. A separate rolled-back probe positively refused session-less closed entry and accepted session-less open entry with null owner. |
| Conversation creation SQL and measured repository state | API contract; Primary evidence; manifest; gap register; disposition; map | WRITE | Generator-owned artifacts remain in scope; ledger and surfaces will be read fresh from Primary after deployment. CHAT-2, the independent direct lifecycle gap, is recorded open and is not repaired here. |

Unresolved Material Consumers: None

The observed direct `started_at` backdate has no established current function/view/policy consumer beyond the stored row; this contract does not invent a timestamp rule. Direct UPDATE lifecycle events and `closed_at` divergence are separately reproduced CHAT-2 and outside this creation repair.

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Focused creation tests, clean reset, pgTAP A/B, six HTTP suites, smoke and installed mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| CHAT-1, ENTRY-1 instance, CHAT-2 and 20/77 disposition match actual evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Manifest and Primary ledger/function/structure agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest test totals agree with actual plans | AFTER_IRREVERSIBLE_ACTION | Step 2 | Step 7 | Step 8 |
| Map and API contract match their generators | BEFORE_COMPLETION | Step 7 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: `app.enforce_status_transition` fires on UPDATE only; `app.guard_write_capability` checks SEND_MESSAGE but not initial state, creator or events; RLS tests scope against caller-controlled owner fields. The RPC alone supplies correct creation values and event. Reuse `app.record_event`, `app.current_placement()`, the existing capability trigger and catalog/RLS constraints; no shared entry or event framework is earned.

Added Property: a successful authenticated INSERT through either door begins `open` under the actual creator/placement and emits exactly one `conversation_started` event with the owning conversation and original payload; refused writes emit none.

Causal Negative: A real SEND_MESSAGE employee saw the customer, inserted `closed` with null `closed_at` and zero events, then inserted `open` naming a colleague and persisted that owner. An authorized direct `open` conversation had zero `conversation_started` timeline entries while the same actor's RPC had one. All probes rolled back.

Positive Test Design: Prove a real employee's direct and RPC creations each persist an `open` row and exactly one event/timeline entry with actual owner, placement, actor and payload; prove a colleague in another department sees zero rows after attempted owner forgery; preserve unique external thread, tenant/catalog/subscription controls and session-less null actor.

Negative Test Design: Prove signed-in and session-less `closed` or pre-closed entry is refused; a trainee lacking SEND_MESSAGE is refused despite a visible customer; a false owner supplied on direct INSERT is replaced with the real creator; duplicate external thread and invalid channel still fail with no extra event.

Non-Empty Population Obligation: Count the visible parent customer, employee and trainee capabilities, each inserted conversation ID, actual owner/scope and events by ID; no zero-row operation may satisfy creation or denial assertions.

Mutation Obligation: Positively disable the creation guard and observe closed entry plus false owner persist; restore exact enabled state. Positively disable the event trigger and observe successful direct creation with zero event; restore. Restore the RPC's old explicit event call alongside the trigger and observe two events for one RPC creation; then restore exact RPC source. Mutation apply failures are harness errors.

Post-Implementation Proof Obligation: Focused permanent pgTAP, two full passes, six HTTP suites, smoke, installed mutation proof, generated artifacts, clean local/Primary parity and repository Gate on final bytes.

## Implementation Steps

1. **Check** that `supabase/migrations/20260924170000_conversation_creation_parity.sql` is absent. If absent, create one LF migration. Add one SECURITY INVOKER `app.guard_conversation_creation()` with `search_path=''`, PUBLIC EXECUTE revoked, attached as a row-level BEFORE INSERT trigger only on `public.conversations`. For every caller require `conversation_status_code='open'` and `closed_at IS NULL` (SQLSTATE 23514); for signed-in callers resolve `app.current_user_id()` and `app.current_placement()` and require an actual actor/branch (42501), then derive `owner_user_id`, `owner_branch_id`, `owner_department_id`, `current_branch_id`, `current_department_id` from them. For session-less writes preserve the nullable owner/scope fields after the same entry-state check. Do not alter `started_at` or UPDATE semantics. Add one SECURITY INVOKER `app.emit_conversation_started()` with `search_path=''`, PUBLIC EXECUTE revoked, attached as a row-level AFTER INSERT trigger only; call existing `app.record_event` with NEW tenant, conversation ID, `conversation_started`, state `open`, session-matched user or null, and the current RPC's exact channel/customer/lead/booking payload keys. Replace `app.start_conversation(text,uuid,uuid,uuid,uuid)` using its current complete definition, removing only the explicit `app.record_event` block; preserve signature, authorization, placement, insert, return, SECURITY INVOKER, search path and authenticated EXECUTE. No other trigger, function, grant, policy, constraint or event type changes. If target file exists with different bytes, stop.
2. **Check** that `supabase/tests/125_conversation_creation_parity_test.sql` is absent. If absent, create one LF transaction-rolled-back pgTAP file with `-- ATTACK-CLASSES:` from the closed vocabulary and exact `plan(N)`. Exercise all Positive/Negative Test Design controls with non-empty row and event counts; assert trigger timing/enabled state and no direct authenticated EXECUTE on either trigger function. Do not modify existing tests. If target exists with different bytes, stop.
3. **Check** whether CHAT-1/CHAT-2 already exist in `reports/master/MASTER_GAP_REGISTER.md` and whether `conversations` is still NOT-RECORDED in `MASTER_SURFACE_DISPOSITION.md`. If absent and unchanged, record CHAT-1 (Medium, fixed creation provenance/event gap), CHAT-2 (Low, open direct lifecycle observability/reopen-time gap) and the `conversations` instance of existing ENTRY-1 as fixed by this migration, with actual actor, operation, result, consumer consequence and proof; do not duplicate ENTRY-1 as a new ID. Set only `conversations` to `AUDITED-OPEN` / `ADVERSARIAL`, session `SPEC-219-conversation-creation-parity`, findings `CHAT-1, CHAT-2, ENTRY-1`. Recompute coverage mechanically as 20/77 and prepend a dated disposition update, preserving history. Do not absorb the deferred CONV-3 integration door or direct UPDATE lifecycle repair. If prior state conflicts, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run a clean local database reset, focused permanent pgTAP, Pass A, six declared HTTP suites, Pass B without reset, `scripts/verify_database.sql`, exact plan sum, installed mutation apply/restore proof, API-contract generator, `git diff --check`, repository consistency and applicable parity readiness. Record exact counts, hashes, exits and any expected undeployed-only reds. Do not ask for Primary authorization until local evidence is complete.
5. **Check** that owner authorization for exact migration and test SHA-256 values is recorded in the Execution Log. If absent, stop after Step 4 and present the exact Primary authorization gate for `vrvtsxexkiiiivlkdxzp`, current HEAD, both file hashes, fresh full Primary baseline and predicted structural delta. Never treat CR approval as deployment authorization.
6. **Check** that Primary lacks `20260924170000_conversation_creation_parity`. If absent and separately authorized, immediately re-read project identity, HEAD, hashes, full ordered ledger, migration absence and conversation row count; any material mismatch invalidates authorization. Apply only the frozen migration. If the connector assigns a temporary version, normalize only its newly inserted row with a guarded uniqueness check. Read fresh full ordered ledger, function and all ten structural surfaces, changed definitions/triggers/privileges and data preconditions. Never contact Secondary.
7. **Check** that fresh Primary evidence includes the new migration identity. If so, rewrite `reports/evidence/primary-ledger-evidence.json` only from Primary reads; update manifest measured migration/function/structure and test totals, coverage 20/77, Last Completed SPEC-219 and Next Capability Slice 20 without starting it. Regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` only with generators. Run ledger, parity-evidence and repository consistency checks. If Primary is not proven, stop.
8. **Check** for a `Post-deploy verification` Execution Log entry. If absent, run canonical `-Finish` and require `LOCAL_CERTIFY: READY`; append results. Independently Review the actual committed scope and every criterion. Only after `Verdict: Confirmed Complete`, set Runtime Checkpoint DONE, transition Complete and clear the manifest pointer. Publish through `publish_candidate.ps1`, require exact-SHA candidate CI, promote the same accepted SHA, require `REMOTE_CERTIFY: READY` and synchronized clean refs. Remove Slice-19 scratch residue. Do not begin Slice 20.

## Acceptance Criteria

- [ ] Direct and RPC conversation creation each persist an `open` row and exactly one correctly scoped `conversation_started` event; refused writes emit none.
- [ ] Authenticated creation derives actual owner and initial branch/department scope; terminal/pre-closed entry is refused for signed-in and session-less writes; valid session-less fixtures keep null actor and permitted shape.
- [ ] Existing lifecycle, message, tenant, capability, catalog, subscription and external-thread controls remain proven; CHAT-2 stays separately open.
- [ ] CHAT-1 and the `conversations` ENTRY-1 instance are recorded fixed; `conversations` is `AUDITED-OPEN` / `ADVERSARIAL` at mechanically correct 20/77 coverage.
- [ ] Migration/test identities, generated artifacts, local and fresh Primary evidence agree; no unauthorized file changes.

## Execution Log

### 2026-09-24 — Live selection and pre-approval audit

Outcome: Drafted after live selector chose `conversations` (Exposure 11, coverage 66) over `payments` (11/84). Local rollback probes established the creation defect, customer-timeline omission, false owner, separate direct-reopen gap and exact prototype behavior. A further rolled-back RLS probe moved the named colleague to another department: the unguarded forged-owner row was visible to that colleague (one row), while the guarded row derived the actual creator and was invisible to the colleague (zero rows). Prototype mutation states were positively observed: disabled guard `D` admitted closed entry and false owner, restored `O`; disabled emitter `D` made a persisted direct row emit zero events, restored `O`; restored old RPC event block produced two events, then the no-event prototype source was restored. Final ROLLBACK left zero prototype triggers and fixture rows and restored original RPC source MD5 `f3446078bb45487952da2057eaed115e`. Read-only Primary `vrvtsxexkiiiivlkdxzp` was ACTIVE_HEALTHY at 225 migrations, fingerprint `843250602025735f48e8c860ea12557f`, latest `20260924160000`, with zero conversation rows. An additional rollback prototype moved the entry-state check ahead of the sessionless bypass: a session-less `closed` INSERT was refused with 23514, while an `open` INSERT retained null owner. No Primary write or Secondary contact occurred. Awaiting owner Draft approval.

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

EARN IT: the entry, owner and event discrepancies persisted on real authorized rows; `app.customer_timeline` omitted the direct start, and the owner field is an RLS scope input. WORTH IT: leaving the direct door as-is preserves an impossible terminal entry and false responsibility; revoking authenticated INSERT breaks the SECURITY INVOKER RPC, and a shared entry/event framework would touch seven unreviewed state-machine surfaces. One conversation-local BEFORE INSERT guard plus one AFTER INSERT emitter and removal of the RPC's duplicate event producer is the narrowest prototype-proven repair. The independently reproduced CHAT-2 direct lifecycle gap requires different UPDATE/reason semantics and remains explicitly open; CONV-3 remains deferred to integration design. Caller-supplied `started_at` was observed but has no established current consumer and did not earn a separate rule.
