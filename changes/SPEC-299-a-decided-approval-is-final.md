# Change Request — SPEC-299

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Batch 6 Slice 44 makes a decided approval request final on every door, makes an approval obey the parent-state rule on every door, and allows one pending finance request per booking item (AR-1, AR-2, AR-3).

## Business Reason

- **Selection.** `scripts/batch6_select_target.ps1` at `a4fc1e1`, on the live local catalog, ranks `approval_requests` first: Exposure 7, coverage 52, NOT-RECORDED (runner-up `user_branch_assignments` 7/590). The manifest's Next capability names that selector, never a copy of its result.
- **The rule.** A finance approval is decided once: `app.review_finance_approval` refuses a request that is not `pending`, and `app.request_finance_approval` refuses a second pending request for an item. Neither check is a rule. The review reads the request without a lock and updates it `where id =` with no status predicate; the request RPC checks with a plain `exists`. RLS `scope_update` opens the table to the reviewer the request type names, by design, and no rule bound what that door could write.
- **Measured at `a4fc1e1`** on the local stack, two live sessions (A acts, sleeps 4 s, commits; B acts 1.5 s later):
  - **AR-1 (High).** A approved and B rejected the same request: both succeeded; the request and the item ended `rejected` with `cost_locked_at` still set from the approval. A finance manager withdrew the requirement (committed); another's approval, queued on the request row, overwrote `cancelled` with `approved` and locked the cost of an item whose requirement was withdrawn.
  - **AR-2 (Medium).** Two requests for one item both returned an id: B waited 2.7 s on the item row, then inserted; two pending requests and two events.
  - **AR-3 (Medium).** After an RPC rejection, a finance manager's plain `update` turned the request `approved` (item still `rejected`, no event), and approved a pending request on a CANCELLED booking that the RPC refuses.
  The sleep only widens the window; any two overlapping calls may interleave this way.
- **The repair.** `app.guard_approval_request_decision`, BEFORE UPDATE OF `approval_status_code` (SECURITY DEFINER, empty `search_path`, executable by no client role): the status leaves only `pending`, and only for `approved`, `rejected` or `cancelled`, the values the two writers assign. The trigger sees the row version current at write time, so a queued second reviewer meets the request already decided and is refused 23514 whatever its earlier read said. An approval of a booking-item request obeys the RPC's parent-state rule (item not archived, cancelled or no_show; booking not archived, completed or cancelled) on every door. A partial UNIQUE index `approval_requests_one_pending_finance_per_item` on (`booking_item_id`) where a `finance_execution_approval` is `pending`: a second pending request on any path waits for the first and is refused 23505. Like `app.enforce_status_transition`, the guard steps aside when there is no end user. No RPC body, grant, policy or `app.status_transitions` row changes.
- **Why not `app.status_transitions`.** It keys one permission per transition; approval authority is per request type (`scope_update`), and `cancelled` comes from the requester's RPC decision and from WITHDRAW_FINANCE_APPROVAL alike. The guard checks validity only and moves no authority.
- **Swept and found sound, pinned rather than changed:** an employee's direct update touches no row (RLS); reviewer and time are derived by `approval_requests_derive_reviewer`; an approval granted first cannot be withdrawn after (the item guard refuses "already granted").
- **Recorded positions, not repaired:** a direct approval of a still-pending request leaves the item pending with no cost lock and no event (an authorized reviewer, no money effect; reopening trigger: a consumer that reads the request instead of the item). A `ceo` or `owner` may approve their own request (reopening trigger: an owner separation-of-duties policy). The RPC's requester-`cancelled` branch is unreachable because the item guard charges APPROVE_FINANCE (reopening trigger: a requester-cancel requirement).
- **Latent on Primary:** `vrvtsxexkiiiivlkdxzp` holds 0 approval requests (read-only, 2026-11-09, ledger 254), so the index cannot meet a duplicate there and no data repair is needed.

## Risks

- **A duplicate pending request already stored would stop the migration.** `create unique index` refuses it and the whole migration rolls back before anything changes (observed on a stack holding a mutant race's duplicate). Step 5 reads Primary for pending duplicates, and Step 7 re-reads them immediately before deployment.
- **A second reviewer or requester now fails instead of overwriting:** 23514 or 23505 after waiting for the first transaction (2.7 s in the race). The RPC callers already treat an error as a refusal.
- **Primary deployment is irreversible** and runs only under the exact-SHA Gate-2 record of Step 6. Approval of this contract does not authorize it. Secondary `brplkqmbzffpxqgkkdzo` is never contacted.
- **Gate 1 and Gate 2 of this contract are DELEGATED** under the owner's instructions (class authorization for Batch 6 releases and standing approval of proposals, 2026-11-08 ~10:20 Cairo; publish and promote ~12:05; slice 2 alongside WS-034, 2026-11-09 ~13:13; "go with your recommendation" ~14:00), recorded outside this repository; never a human-typed digest.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-299-a-decided-approval-is-final.md`
- `supabase/migrations/20261109120000_a_decided_approval_is_final.sql`
- `supabase/tests/159_a_decided_approval_is_final_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607042500_create_finance_transaction_tables.sql`
- `supabase/migrations/202607046000_request_finance_approval.sql`
- `supabase/migrations/202607046100_review_finance_approval.sql`
- `supabase/migrations/202607052400_financial_write_authority.sql`
- `supabase/migrations/202607056500_action_attributions_are_derived.sql`
- `supabase/migrations/202607059400_the_parents_state_is_a_rule_on_every_door.sql`
- `supabase/migrations/20260909134000_a_finance_requirement_withdrawn_only_deliberately.sql`
- `supabase/tests/20_approval_subject_integrity_test.sql`
- `supabase/tests/29_financial_write_authority_test.sql`
- `supabase/tests/88_parent_state_on_every_door_test.sql`
- `supabase/tests/115_finance_withdrawal_and_reassignment_authority_test.sql`
- `supabase/tests/10_grant_model_test.sql`
- `scripts/verify_database.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/parity_surface.sql`
- `scripts/check_database_parity.ps1`
- `scripts/check_primary_ledger.ps1`
- `ENGINEERING_METHOD.md`
- `CR_LIFECYCLE.md`
- `changes/TEMPLATE.md`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `reports/architecture-decision-records.md`
- `reports/future-backlog.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `supabase/migrations/202607046000_request_finance_approval.sql`, `202607046100_review_finance_approval.sql` and `20260909134000_a_finance_requirement_withdrawn_only_deliberately.sql` (the three writers)
- `supabase/migrations/202607052400_financial_write_authority.sql` (`scope_update`) and `202607059400_the_parents_state_is_a_rule_on_every_door.sql` (the parent rule, insert only on this table)
- `reports/master/MASTER_GAP_REGISTER.md`; `reports/master/MASTER_SURFACE_DISPOSITION.md`; `reports/master/MASTER_EXECUTION_PLAN.md`, Batch 6 method, EC-1…EC-11
- `changes/SPEC-298-a-due-retry-is-opened-once.md` (the last Primary-deploying slice)

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
- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: SPEC-299-V1 adds a validity guard on the request status (a decided request is final; an approval obeys the parent-state rule) and a partial unique index (one pending finance request per item); test 159 pins the index, the finality on every door, the withdrawn and cancelled-booking cases and an unaffected non-status edit; the register and disposition record AR-1 to AR-3 and the surface.

Pass 2 Adversarial Review: SPEC-299-V2 challenged each part. Locking the request `for update` inside `app.review_finance_approval` was rejected: it fixes one RPC, leaves the direct door (AR-3) and the withdraw race to separate code, and rewrites a body the guard leaves untouched. Registering the transitions in `app.status_transitions` was rejected: it keys one permission per transition, which cannot express per-type authority or two authorities for `cancelled`. A transaction-local flag set by the RPCs, so that only they may decide, was rejected: it changes three RPC bodies and still trusts the flag's setter. Closing the direct approval of a pending request (the item stays pending) was rejected for this slice: an authorized reviewer, no money effect, recorded with its reopening trigger. A unique index over every request type was rejected: only finance approval has the one-per-item rule. Copying the selector's next target into the manifest was rejected (SPEC-270; SPEC-278's cancellation).

Pass 3 Evidence Refresh: 2026-11-09. SPEC-299-V3 re-measured on byte-identical files in a disposable clone of `a4fc1e1` with the project-local CLI 3.0.0: the clean reset, test 159, pgTAP Pass A and B, the three HTTP suites, smoke, the races, both mutants, the causal negative, the structural fingerprints before and after, and repository consistency (Consumer Closure); and read Primary read-only for its ledger and its approval requests.

Selected Version: SPEC-299-V3; selected: the smallest repair that closes AR-1 to AR-3 on every door (one validity guard, one partial unique index, no RPC body changed), proven on byte-identical files by the full local protocol, two killed mutants, the races and the causal negative

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A decided approval request is final, and an approval obeys the parent-state rule, on every door | `app.review_finance_approval`; `app.withdraw_finance_approval`; the reviewer's table door (`scope_update`); any platform writer | WRITE | Migration SHA-256 `eb2ca6ddab68e7af8805d06177fa9d109002296a8b62733596841f136654816c`, md5 `8aaf23a30dd68393dcd8acd7c81325c7`, 5544 bytes, LF, ASCII. A clean reset gives 255 migrations, latest `20261109120000`, guard `md5(prosrc)` `b8669055544c146de381d62de189ea5f`, SECURITY DEFINER, ACL `{postgres=X/postgres}`. |
| One pending finance request per booking item | `app.request_finance_approval`; the requester's insert | WRITE | A second pending request is refused 23505 on the table door; in the race B is refused after waiting for A. |
| Overlapping reviews, a review racing a withdrawal | the two reviewers; the withdrawer; the booking item's cost lock | WRITE | Races on the final bytes: `approved -> rejected` and `cancelled -> approved` refused 23514; request and item agree; no cost lock on a withdrawn item. |
| The RPC bodies, the item guards and the derived reviewer | `app.guard_booking_item_financials`; `approval_requests_derive_reviewer`; tests 20, 29, 88, 115 | VERIFY | No body changes; every pgTAP file passes. |
| Test 159 | `supabase/tests` | WRITE | SHA-256 `775d659910260ccfb886ba1147d5419f118cb4cb2ad7d22414d401204c56ef40`, md5 `6b6757f2bbfa90a70a752b00cdbd581d`, 9726 bytes, LF, ASCII, `plan(14)`: 14/14. |
| Other tests and the suite | the full pgTAP suite; the HTTP suites | VERIFY | Pass A `Files=159, Tests=3024`, PASS; HTTP 35/0, 85/0, 122/0; Pass B 159/3024, PASS. 159 files whose literal `plan(N)` values sum to 3024. |
| Smoke | `scripts/verify_database.sql` | VERIFY | `ALL CHECKS PASSED` (78 tables, 71/623 catalog). No table, catalog value, policy, grant or transition is added. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | Before (254): `_combined` `2a15deb38b76a75b9da991b955ea31b3`/3137, equal to the recorded Primary evidence. After (255): functions `b85385fc150c11088ec13f5dcfc0b889`/333 (+1), triggers `be5a19f32b8215cb33cc24c7989a9cbf`/320 (+1), indexes `d596c15bc684a9e75a43b582050602ec`/301 (+1), `_combined` `04223971cbe8be586da4135ddcfbfe06`/3140; the rest unchanged. Step 8 writes Primary values only from fresh post-deploy readings. |
| Client API | `MASTER_API_CONTRACT.md` (Check L3) | VERIFY | No RPC is added, removed or changed in signature; the guard is a trigger function executable by no client role. In Write Scope because a migration makes Check L3 apply. |
| Measured state that moves | manifest `Live state` and suite figure; `primary-ledger-evidence.json`; `ai-map.json` and `repository-index.md` | WRITE | 254 → 255 migrations, latest `20261109120000`, ledger fingerprint `7b2e96f12929492376da52621efe840c`; 158 → 159 files and 3010 → 3024 assertions; coverage 44 → 45 of 78. Catalog 71/623, tables 78 and client RPCs 80 do not move. `Next capability` and `Current Module` stay unchanged (selector form). |
| The pinned manifest lines `Current Module`, `Next capability` and `Batch 6 surface coverage` | native Boot; `scripts/batch6_select_target.ps1` and `MASTER_SURFACE_DISPOSITION.md`, which own their values (GOVERNANCE.md §6 rule 10) | UNAFFECTED | Step 9 names `Current Module` and `Next capability` only to leave them unchanged; each line keeps its ratified text and pin, so the selector and the disposition record name the next slice and the coverage. |
| AR-1 to AR-3 fixed; the surface recorded | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24, 25, 29 | WRITE | No `AR-` row exists at `a4fc1e1`. Test 159's `-- ATTACK-CLASSES:` line declares nine classes with OBSERVABILITY `=N/A` and carries negative assertions, so Check 24 admits `ADVERSARIAL`. Each AR row has Owner `—` and is settled. Coverage 45: 21 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 33 `NOT-RECORDED`; all 45 `ADVERSARIAL`. |
| CI-only guard self-tests and repository consistency | `scripts/test_*_guard.ps1` (four); `scripts/check_repository_consistency.ps1` | VERIFY | With Steps 1–4 applied, consistency reports exactly seven measured-state items (254 vs 255 migrations, latest, ledger fingerprint, 158 vs 159 files, 3010 vs 3024 assertions, the Primary-evidence record twice) and Checks 21–29 pass. Step 8 makes them true; the one implementation commit is made only after it. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 7 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| The applied files equal the verified bytes, and the focused tests, mutants, races and causal negative hold | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Primary holds no duplicate pending finance request and lacks the target migration | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 7 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 8 | Step 9 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 2 | Step 8 | Step 9 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 8 | Step 9 |
| The four CI-only guard self-tests pass | BEFORE_COMPLETION | Step 1 | Step 8 | Step 9 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: `app.review_finance_approval` checks `pending` on an unlocked read and updates with no status predicate; `app.request_finance_approval` checks with a plain `exists`; `app.withdraw_finance_approval` locks the item and closes only pending requests; the parent-state guard on this table is `before insert` only; `app.status_transitions` holds no `approval_requests` row and keys one permission per transition. No constraint, lock or trigger stops a decided request from being re-decided or a second pending request from being inserted.

Added Property: For every end-user writer, an approval request's status leaves `pending` once and never returns or changes again, an approval of a booking-item request obeys the parent-state rule, and a booking item holds at most one pending finance request.

Causal Negative: On the stack with the guard, its function and the index removed (the `a4fc1e1` schema), test 159 fails assertions 1 and 3–5 and stops, and the races return: two pending requests for one item; a request and item `rejected` with the cost locked; an approval over a withdrawal with the requirement off and the cost locked; a direct approve after rejection and on a cancelled booking.

Positive Test Design: One tenant with an employee requester and a finance manager reviewer at `aal2`; two bookings, four items. Positive controls: four requests open through the RPC; the reviewer approves item 1 (request and item `approved`, cost locked), rejects item 2 and withdraws item 3 through the RPCs; a payload edit lands; a direct rejection on the cancelled booking lands.

Negative Test Design:
- **Key:** a second pending request for item 1 on the table door is refused 23505.
- **State:** `approved -> rejected` and `approved -> pending` are refused 23514; `rejected -> approved` is refused 23514.
- **Concurrency (pinned on the door the race reaches):** an approval of the withdrawn (`cancelled`) request is refused 23514.
- **Business:** a direct approval on the cancelled booking is refused 23514.
- **Door:** every refusal above is on the reviewer's own table door, which RLS opens by design.

Non-Empty Population Obligation: The fixture holds one tenant with two users, two bookings and four items, each with one pending request. Each refusal is asserted by exact SQLSTATE and each agreement by an exact boolean.

Mutation Obligation: Each mutant is installed on the prototype stack, proven installed by a changed fingerprint (trigger count, index count, guard `md5(prosrc)`), run against test 159 and the races, then restored and proven equal (`trg=1 idx=1 fn=b8669055544c146de381d62de189ea5f`) with 14/14 before the next. A mutant not proven installed is a harness error, never a kill. A mutant's race leaves duplicate pending rows; they are retired (disposable data) before the index is restored.

| Mutant | Change | Killed on the prototype by |
| --- | --- | --- |
| M1 | the guard trigger dropped | 159 assertions 5–7, 10, 12–13; the races return `rejected` with the cost locked, an approval over a withdrawal, and both direct approvals |
| M2 | the unique index dropped | 159 assertions 1 and 3–5; the race returns two pending requests |

Post-Implementation Proof Obligation: All of the following on the final bytes, through canonical `-Finish` from the main checkout with the project-local CLI: the clean reset, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke; the generated artifacts, repository consistency and the recorded Primary evidence. Before Step 7: the focused tests, the mutants, the races, the causal negative and the fresh Primary baseline of Step 5.

## Implementation Steps

1. Check whether `supabase/migrations/20261109120000_a_decided_approval_is_final.sql` contains `SPEC-299 (Batch 6 Slice 44, AR-1, AR-2, AR-3)`; if so record Already Applied when its Git blob is 0fb6b37c21d7386e97794e144e30099e9807b825, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the migration: the decision guard and the one-pending-request index), and change nothing else:

   ```text
   -- SPEC-299 (Batch 6 Slice 44, AR-1, AR-2, AR-3) -- a decided approval request is final,
   -- and an item has at most one pending finance request, on every door.
   --
   -- =================================================================================================
   -- THE MEASURED DEFECTS (2026-11-09 at a4fc1e1 on the local stack, two live sessions; session A
   -- acts, sleeps 4 s, commits; session B acts 1.5 s later)
   --
   -- AR-1 `app.review_finance_approval` reads the request without a lock and updates it `where id =`
   --      with no status predicate, so the `pending` check it made can be stale by the time it writes.
   --      A approves, B rejects: both succeed; the request ends `rejected`, the item `rejected`, and
   --      `cost_locked_at` stays set from the approval. A withdraws (committed), B approves: B waits
   --      on the request row, then overwrites `cancelled` with `approved` and locks the cost of an
   --      item whose finance requirement was withdrawn.
   -- AR-2 `app.request_finance_approval` refuses a second pending request with a plain `exists`, and
   --      nothing makes "one pending finance request per item" a rule. Two overlapping requests both
   --      insert: two pending requests for one item.
   -- AR-3 The table door (`scope_update`, open by design to the reviewer the type names) had no
   --      transition rule. A finance manager turned a `rejected` request `approved` by plain SQL, and
   --      approved a pending request on a CANCELLED booking that the RPC refuses.
   --
   -- =================================================================================================
   -- THE REPAIR, AND WHY THIS SHAPE
   --
   -- 1. `app.guard_approval_request_decision`, BEFORE UPDATE OF approval_status_code: the status may
   --    only leave `pending`, and only for `approved`, `rejected` or `cancelled` -- the three values
   --    the two writers (`app.review_finance_approval`, `app.withdraw_finance_approval`) assign. A
   --    decided request is final. Because the trigger sees the row version current at write time,
   --    it also closes AR-1: a second reviewer queued behind the first finds OLD already decided and
   --    is refused 23514, whatever its earlier read said. An approval of a booking-item request obeys
   --    the RPC's parent-state rule (item not archived, cancelled or no_show; booking not archived,
   --    completed or cancelled) on every door.
   -- 2. A partial UNIQUE index: one `pending` `finance_execution_approval` per booking item. A
   --    second pending request on any path waits for the first and is refused 23505.
   --
   -- Authority is NOT moved: RLS `scope_update` already names the permission per request type, and
   -- `app.status_transitions` keys one permission per transition, which cannot express that (a
   -- `cancelled` comes from the requester's RPC decision and from WITHDRAW_FINANCE_APPROVAL alike).
   -- The guard is validity only, so it is not registered there.
   --
   -- Like `app.enforce_status_transition`, the guard steps aside when there is no end user
   -- (`auth.uid()` is null): migrations, seeds and the platform's own maintenance.
   --
   -- NOT CHANGED: every grant, policy, both RPC bodies, `app.status_transitions`, the item guards.
   -- Hosted rows at the time of writing: 0 approval requests on Primary (read-only, ledger 254), so
   -- the index meets no duplicate.
   -- =================================================================================================

   create or replace function app.guard_approval_request_decision()
   returns trigger
   language plpgsql
   security definer
   set search_path to ''
   as $$
   declare
       v_parent record;
   begin
       if (select auth.uid()) is null then
           return new;
       end if;
       if new.approval_status_code is not distinct from old.approval_status_code then
           return new;
       end if;
       if old.approval_status_code <> 'pending'
          or new.approval_status_code not in ('approved', 'rejected', 'cancelled') then
           raise exception
               '% -> % is not a permitted transition for approval_requests: a decided request is final',
               old.approval_status_code, coalesce(new.approval_status_code, '(null)')
               using errcode = '23514';
       end if;
       if new.approval_status_code = 'approved' and new.booking_item_id is not null then
           select bi.is_archived as item_archived, bi.base_status_code,
                  b.is_archived as booking_archived, b.booking_status_code
             into v_parent
           from public.booking_items bi
           join public.bookings b on b.id = bi.booking_id
           where bi.id = new.booking_item_id;
           if v_parent.item_archived
              or v_parent.base_status_code in ('cancelled', 'no_show')
              or v_parent.booking_archived
              or v_parent.booking_status_code in ('completed', 'cancelled') then
               raise exception 'cannot approve a request for a terminal/archived booking item or booking'
                   using errcode = '23514';
           end if;
       end if;
       return new;
   end;
   $$;

   revoke execute on function app.guard_approval_request_decision() from public;

   drop trigger if exists approval_requests_guard_decision on public.approval_requests;
   create trigger approval_requests_guard_decision
       before update of approval_status_code on public.approval_requests
       for each row execute function app.guard_approval_request_decision();

   create unique index if not exists approval_requests_one_pending_finance_per_item
       on public.approval_requests (booking_item_id)
       where approval_type_code = 'finance_execution_approval' and approval_status_code = 'pending';
   ```

   The resulting file's Git blob is 0fb6b37c21d7386e97794e144e30099e9807b825.

2. Check whether `supabase/tests/159_a_decided_approval_is_final_test.sql` contains `plan(14)`; if so record Already Applied when its Git blob is 282d80dcc2f126e7a2ff9e13ed6a37ef4b5b5e74, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (test 159, 14 assertions), and change nothing else:

   ```text
   -- pgTAP: SPEC-299 (Batch 6 Slice 44, AR-1, AR-2, AR-3) -- a decided approval request is
   -- final, and an item has at most one pending finance request (`20261109120000`).
   -- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT CONCURRENCY REPLAY PRIVILEGE BUSINESS OBSERVABILITY=N/A
   --   OBSERVABILITY=N/A -- the guard refuses; it records nothing, and the RPCs' events are pinned by
   --     their own tests.
   --   CONCURRENCY -- two overlapping reviews or requests need two live sessions, which pgTAP does not
   --     have. The races are proven by the Batch 6 two-session probe, with and without the repair;
   --     here the rule they rest on is pinned on every door: a queued second reviewer meets OLD
   --     already decided, which is exactly the direct UPDATE below.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(14);

   insert into auth.users (id, email) values
     ('15900000-0000-0000-0000-0000000000a1','emp@c159.test'),
     ('15900000-0000-0000-0000-0000000000a2','fin@c159.test');
   insert into public.tenants (id, name, slug, status) values
     ('15900000-0000-0000-0000-000000000001','Approvals Travel','approvals-travel','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select '15900000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug) values
     ('15900000-0000-0000-0000-00000000000a','15900000-0000-0000-0000-000000000001','Main','main-159');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
     ('15900000-0000-0000-0000-0000000000c1','15900000-0000-0000-0000-000000000001','15900000-0000-0000-0000-00000000000a','sales','Sales');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('15900000-0000-0000-0000-000000000011','15900000-0000-0000-0000-000000000001','Employee','emp@c159.test',true,'15900000-0000-0000-0000-0000000000a1'),
     ('15900000-0000-0000-0000-000000000012','15900000-0000-0000-0000-000000000001','Finance','fin@c159.test',true,'15900000-0000-0000-0000-0000000000a2');
   insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
   select '15900000-0000-0000-0000-000000000001', u, '15900000-0000-0000-0000-00000000000a', '15900000-0000-0000-0000-0000000000c1', true
   from unnest(array['15900000-0000-0000-0000-000000000011'::uuid,'15900000-0000-0000-0000-000000000012']) u;
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select '15900000-0000-0000-0000-000000000001', v.uid, r.id, 'tenant'
   from (values ('15900000-0000-0000-0000-000000000011'::uuid,'employee'),
                ('15900000-0000-0000-0000-000000000012'::uuid,'finance_manager')) v(uid, role_code)
   join public.roles r on r.code = v.role_code;
   insert into public.customers (id, tenant_id, customer_type_code, full_name) values
     ('15900000-0000-0000-0000-0000000000d1','15900000-0000-0000-0000-000000000001','person','Customer');
   insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                                owner_branch_id, owner_department_id, booking_status_code, title, booking_reference)
   select b.id, '15900000-0000-0000-0000-000000000001', '15900000-0000-0000-0000-00000000000a', '15900000-0000-0000-0000-0000000000c1',
          '15900000-0000-0000-0000-0000000000d1', '15900000-0000-0000-0000-000000000011',
          '15900000-0000-0000-0000-00000000000a', '15900000-0000-0000-0000-0000000000c1', 'draft', 'Booking', b.ref
   from (values ('15900000-0000-0000-0000-0000000000f1'::uuid,'BK-159-1'), ('15900000-0000-0000-0000-0000000000f2'::uuid,'BK-159-2')) b(id, ref);
   insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code,
                                     owner_user_id, owner_branch_id, owner_department_id,
                                     currency_code, cost_amount, selling_amount)
   select i.id, '15900000-0000-0000-0000-000000000001', i.booking, 'hotel', 'draft',
          '15900000-0000-0000-0000-000000000011', '15900000-0000-0000-0000-00000000000a', '15900000-0000-0000-0000-0000000000c1',
          'EGP', 3000, 5000
   from (values ('15900000-0000-0000-0000-0000000000e1'::uuid,'15900000-0000-0000-0000-0000000000f1'::uuid),
                ('15900000-0000-0000-0000-0000000000e2'::uuid,'15900000-0000-0000-0000-0000000000f1'::uuid),
                ('15900000-0000-0000-0000-0000000000e3'::uuid,'15900000-0000-0000-0000-0000000000f1'::uuid),
                ('15900000-0000-0000-0000-0000000000e4'::uuid,'15900000-0000-0000-0000-0000000000f2'::uuid)) i(id, booking);

   select is(
     (select count(*)::int from pg_indexes
      where schemaname = 'public' and indexname = 'approval_requests_one_pending_finance_per_item'
        and indexdef like '%UNIQUE%' and indexdef like '%pending%'),
     1,
     'AR-2: one pending finance request per booking item is a unique rule, not an RPC check');

   -- The employee requests finance approval on items 1-4 through the RPC.
   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"15900000-0000-0000-0000-0000000000a1"}', true);
   select lives_ok(
     $$select app.request_finance_approval(i, 'needs sign-off') from unnest(array[
         '15900000-0000-0000-0000-0000000000e1'::uuid, '15900000-0000-0000-0000-0000000000e2',
         '15900000-0000-0000-0000-0000000000e3', '15900000-0000-0000-0000-0000000000e4']) i$$,
     'the requester opens one pending finance request on each of four items');

   select throws_ok(
     $$insert into public.approval_requests (tenant_id, approval_type_code, approval_status_code, related_entity_type,
                                             related_entity_id, booking_item_id, reason)
       values ('15900000-0000-0000-0000-000000000001', 'finance_execution_approval', 'pending', 'booking_item',
               '15900000-0000-0000-0000-0000000000e1', '15900000-0000-0000-0000-0000000000e1', 'again')$$,
     '23505', null,
     'AR-2: a second pending finance request for the same item is refused on the table door too -- an overlapping RPC call meets the same key');

   -- The finance manager decides.
   select set_config('request.jwt.claims', '{"sub":"15900000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
   select lives_ok(
     $$select app.review_finance_approval((select id from public.approval_requests where booking_item_id = '15900000-0000-0000-0000-0000000000e1'), 'approved', 'ok')$$,
     'the reviewer approves item 1 through the RPC');

   select throws_ok(
     $$update public.approval_requests set approval_status_code = 'rejected'
       where booking_item_id = '15900000-0000-0000-0000-0000000000e1'$$,
     '23514', null,
     'AR-1: approved -> rejected is refused -- the write a second reviewer queued behind the first makes, after its stale pending check');

   select is(
     (select bi.cost_locked_at is not null and bi.finance_approval_status_code = 'approved' and ar.approval_status_code = 'approved'
      from public.booking_items bi join public.approval_requests ar on ar.booking_item_id = bi.id
      where bi.id = '15900000-0000-0000-0000-0000000000e1'),
     true,
     '...so the request and the item agree: approved, with the cost locked');

   select throws_ok(
     $$update public.approval_requests set approval_status_code = 'pending'
       where booking_item_id = '15900000-0000-0000-0000-0000000000e1'$$,
     '23514', null,
     'a decided request cannot be reopened either');

   select lives_ok(
     $$update public.approval_requests set payload = '{"note":"filed"}'::jsonb
       where booking_item_id = '15900000-0000-0000-0000-0000000000e1'$$,
     'an edit that does not move the status is unaffected -- the guard fires on decisions only');

   select lives_ok(
     $$select app.review_finance_approval((select id from public.approval_requests where booking_item_id = '15900000-0000-0000-0000-0000000000e2'), 'rejected', 'over budget')$$,
     'the reviewer rejects item 2 through the RPC');

   select throws_ok(
     $$update public.approval_requests set approval_status_code = 'approved'
       where booking_item_id = '15900000-0000-0000-0000-0000000000e2'$$,
     '23514', null,
     'AR-3: rejected -> approved by plain SQL is refused (measured before the repair: accepted, item left rejected)');

   select lives_ok(
     $$select app.withdraw_finance_approval('15900000-0000-0000-0000-0000000000e3', 'not needed')$$,
     'the reviewer withdraws item 3''s finance requirement; its pending request is cancelled');

   select throws_ok(
     $$update public.approval_requests set approval_status_code = 'approved'
       where booking_item_id = '15900000-0000-0000-0000-0000000000e3'$$,
     '23514', null,
     'AR-1: an approval cannot land on a withdrawn request (measured before the repair: a queued approval overwrote it and locked the cost)');

   -- Booking 2 is cancelled; its item's request is still pending.
   reset role;
   select set_config('request.jwt.claims', '', true);
   update public.bookings set booking_status_code = 'cancelled' where id = '15900000-0000-0000-0000-0000000000f2';
   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"15900000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
   select throws_ok(
     $$update public.approval_requests set approval_status_code = 'approved'
       where booking_item_id = '15900000-0000-0000-0000-0000000000e4'$$,
     '23514', null,
     'AR-3: the RPC''s parent-state rule holds on the table door -- no approval for a cancelled booking');

   select lives_ok(
     $$update public.approval_requests set approval_status_code = 'rejected'
       where booking_item_id = '15900000-0000-0000-0000-0000000000e4'$$,
     '...while rejecting it stays possible: the rule refuses approval, not closure');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 282d80dcc2f126e7a2ff9e13ed6a37ef4b5b5e74.

3. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `| AR-1 |`; if so record Already Applied when its Git blob is 0628dc28ca4d1972df64589137a4dd6b4448646b, and otherwise stop and report. Otherwise make exactly these 2 edits (the Slice 44 freshness entry and the AR-1 to AR-3 rows), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-08 (**Slice 43 — `notification_deliveries` selected live at Exposure 7, coverage 42; runner-up `approval_requests` at 7/52.** **ND-1** (Medium) is new and fixed. Two overlapping runs of `app.claim_notification_deliveries` each opened attempt 2 of the same due retry and each claimed it, so its recipient would be sent the same message twice. SPEC-298 makes the attempt number unique per chain and has the claim skip an attempt another run has opened. No other row changed.)
   ```
   with
   ```text
   Last updated: 2026-11-09 (**Slice 44 — `approval_requests` selected live at Exposure 7, coverage 52; runner-up `user_branch_assignments` at 7/590.** **AR-1** (High), **AR-2** (Medium) and **AR-3** (Medium) are new and fixed. Two overlapping finance reviews of one request both succeeded, so a request ended `rejected` with its item's cost locked by the approval, and a concurrent approval overwrote a withdrawal; two overlapping requests opened two pending requests for one item; and the reviewer's direct table door turned a `rejected` request `approved` and approved one on a cancelled booking. SPEC-299 makes a decided request final on every door, makes an approval obey the parent-state rule on every door, and allows one pending finance request per item. No other row changed.)

   Previously: 2026-11-08 (**Slice 43 — `notification_deliveries` selected live at Exposure 7, coverage 42; runner-up `approval_requests` at 7/52.** **ND-1** (Medium) is new and fixed. Two overlapping runs of `app.claim_notification_deliveries` each opened attempt 2 of the same due retry and each claimed it, so its recipient would be sent the same message twice. SPEC-298 makes the attempt number unique per chain and has the claim skip an attempt another run has opened. No other row changed.)
   ```

   b) immediately after the line
   ```text
   | ND-1 | **Two overlapping dispatchers could each open the same due notification retry and both send it** | integrity / delivery | Medium | R | 6 | M | ✅ | **✅ FIXED 2026-11-08 (SPEC-298, `20261108120000`), DEPLOYED to Primary under the exact-SHA Gate-2 record of this contract; the fresh Primary ledger, functions and structure equal local.** **MEASURED** at `a21a0ec` on the local stack: one `email` delivery at attempt 1, failed six minutes earlier, so its retry was due; session A ran `begin; select app.claim_notification_deliveries('email', 50); select pg_sleep(4); commit;` and session B ran the same claim 1.5 s later. The chain ended attempt 1 failed and attempt 2 pending and claimed twice, and each session's claim returned the notification once: its recipient would be sent the same message twice. The sleep only widens the window. The claim's step 3 is safe by `for update skip locked`; its step 2, which opens the due retry, was not, because its `not exists` cannot see another run's uncommitted attempt N+1 and nothing made (notification_id, channel_code, attempt_number) unique. **Repaired:** the unique constraint `notification_deliveries_attempt_key` replaces the plain chain index, and step 2 names it in `on conflict ... do nothing`, so a second run waits on the first run's key and skips it (race rerun: session B waited 2.6 s, returned nothing and the chain holds one attempt 2); a second attempt N on any path is refused 23505. Every producer (`app.process_lead_sla` and both credit evaluators) writes attempt 1 for a notification it has just created, so none can collide. No email is sent today (MAIL-1), so no recipient was affected. Pinned by `158_...` and mutants M1 (the key dropped) and M2 (the on-conflict clause removed), each killed, M2 also by the race | — | SPEC-298-a-due-retry-is-opened-once | 11-08 | 11-08 |
   ```
   insert
   ```text
   | AR-1 | **Two overlapping finance reviews of one request both succeeded, and a concurrent approval overwrote a withdrawal, so a rejected or withdrawn request kept its item's cost locked** | financial integrity / concurrency | **High** | R | 6 | M | 🛡 | **FIXED 2026-11-09 locally (SPEC-299, `20261109120000`); Primary deployment pending.** **MEASURED** at `a4fc1e1` on the local stack, two live sessions (A acts, sleeps 4 s, commits; B acts 1.5 s later): A approved and B rejected the same request through `app.review_finance_approval`, and both succeeded; the request and the item ended `rejected` while `cost_locked_at` stayed set from the approval. A finance manager withdrew the requirement (committed) and another's approval, queued on the request row, then overwrote `cancelled` with `approved` and locked the cost of an item whose finance requirement was withdrawn. The RPC reads the request without a lock and updates it `where id =` with no status predicate, so its `pending` check is stale when it writes. **Repaired:** `app.guard_approval_request_decision` (BEFORE UPDATE OF `approval_status_code`, SECURITY DEFINER, empty `search_path`, executable by no client role) lets the status leave only `pending`, and only for `approved`, `rejected` or `cancelled`; a queued second reviewer meets the row already decided and is refused 23514 (race rerun: B refused `approved -> rejected` and `cancelled -> approved`; request and item agree). Authority is not moved. **Latent:** Primary and Founder Secondary held 0 approval requests. Pinned by `159_...` and mutant M1 (the guard dropped), killed by the test and the race | — | SPEC-299-a-decided-approval-is-final | 11-09 | 11-09 |
   | AR-2 | **Two overlapping finance requests for one booking item both opened, leaving two pending requests** | integrity / concurrency | Medium | R | 6 | M | 🛡 | **FIXED 2026-11-09 locally (SPEC-299, `20261109120000`); Primary deployment pending.** **MEASURED** at `a4fc1e1`, two live sessions: both `app.request_finance_approval` calls returned an id; B waited 2.7 s on the item row and then inserted, so the item held two pending requests and two events. The RPC refuses a second pending request with a plain `exists`, and nothing made one pending finance request per item a rule. **Repaired:** the partial unique index `approval_requests_one_pending_finance_per_item` on (`booking_item_id`) where a `finance_execution_approval` is `pending`; a second pending request on any path waits for the first and is refused 23505 (race rerun: B refused). Pinned by `159_...` and mutant M2 (the index dropped), killed by the test and the race | — | SPEC-299-a-decided-approval-is-final | 11-09 | 11-09 |
   | AR-3 | **The reviewer's direct table door changed an approval request outside every rule the RPC keeps** | security / state | Medium | R | 6 | M | 🛡 | **FIXED 2026-11-09 locally (SPEC-299, `20261109120000`); Primary deployment pending.** **MEASURED** at `a4fc1e1`: RLS `scope_update` opens the table to the reviewer the request type names, by design, but no rule bound what that door could write. After an RPC rejection, a finance manager's plain `update` turned the request `approved` (the item stayed `rejected`, no event), and approved a pending request on a CANCELLED booking that the RPC refuses. **Repaired:** the AR-1 guard holds on every door, and an approval of a booking-item request obeys the RPC's parent-state rule (item not archived, cancelled or no_show; booking not archived, completed or cancelled), 23514; a rejection stays possible. **Recorded positions, not repaired:** a direct approval of a still-pending request leaves the item pending with no cost lock and no event (an authorized reviewer, no money effect; reopening trigger: a consumer that reads the request instead of the item); a `ceo` or `owner` may approve their own request (separation of duties is an owner policy; reopening trigger: that policy); the RPC's requester-`cancelled` branch is unreachable because the item guard charges APPROVE_FINANCE (withdrawal covers the need). Pinned by `159_...` | — | SPEC-299-a-decided-approval-is-final | 11-09 | 11-09 |
   ```

   The resulting file's Git blob is 0628dc28ca4d1972df64589137a4dd6b4448646b.

4. Check whether `reports/master/MASTER_SURFACE_DISPOSITION.md` contains `**45 of 78 recorded · 21 `; if so record Already Applied when its Git blob is 196c55813a8c1afcccf01ca4d3b293d1c00538f1, and otherwise stop and report. Otherwise make exactly these 4 edits (the freshness entry, coverage 45 of 78 and the approval_requests row), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-08 (**slice 43 — `notification_deliveries` selected by Exposure 7, coverage 42; runner-up `approval_requests` at 7/52.** Coverage **43 → 44 of 78**. ND-1: two overlapping dispatchers each opened attempt 2 of the same due retry and each claimed it, so its recipient would be sent the message twice. SPEC-298 closes it, so the row is `AUDITED`, with its recorded positions and their reopening triggers. No other row changed.)
   ```
   with
   ```text
   Last updated: 2026-11-09 (**slice 44 — `approval_requests` selected by Exposure 7, coverage 52; runner-up `user_branch_assignments` at 7/590.** Coverage **44 → 45 of 78**. AR-1: two overlapping finance reviews of one request both succeeded, and a concurrent approval overwrote a withdrawal, leaving a rejected or withdrawn request with its item's cost locked. AR-2: two overlapping requests opened two pending requests for one item. AR-3: the reviewer's direct table door rewrote a decided request and approved one on a cancelled booking. SPEC-299 closes all three, so the row is `AUDITED`, with its recorded positions and their reopening triggers. No other row changed.)

   Previously: 2026-11-08 (**slice 43 — `notification_deliveries` selected by Exposure 7, coverage 42; runner-up `approval_requests` at 7/52.** Coverage **43 → 44 of 78**. ND-1: two overlapping dispatchers each opened attempt 2 of the same due retry and each claimed it, so its recipient would be sent the message twice. SPEC-298 closes it, so the row is `AUDITED`, with its recorded positions and their reopening triggers. No other row changed.)
   ```

   b) replace the line
   ```text
   **44 of 78 recorded · 20 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 34 `NOT-RECORDED`.**
   ```
   with
   ```text
   **45 of 78 recorded · 21 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 33 `NOT-RECORDED`.**
   ```

   c) replace the line
   ```text
   **All 44 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```
   with
   ```text
   **All 45 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```

   d) replace the line
   ```text
   | `approval_requests` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `approval_requests` | **AUDITED** | ADVERSARIAL | `SPEC-299-a-decided-approval-is-final` | AR-1, AR-2, AR-3 | `159_a_decided_approval_is_final_test.sql` (14 assertions, nine attack classes declared, OBSERVABILITY N/A) proves that one pending finance request per item is a unique rule refused 23505 on the table door, that a decided request cannot be re-decided or reopened (23514), that an approval cannot land on a withdrawn request, that an approval obeys the parent-state rule on the table door while a rejection stays possible, and that an edit that does not move the status is unaffected. The two-session races and mutants M1 (guard dropped) and M2 (index dropped) were each killed on the prototype; the causal negative (both removed, the `a4fc1e1` schema) brought back every measured race. **Swept and sound:** an employee's direct update touches no row (RLS); approval authority stays per request type in `scope_update`; reviewer and time are derived by `approval_requests_derive_reviewer`; an approval granted first cannot be withdrawn after (the item guard). **Recorded positions, not repaired:** a direct approval of a still-pending request leaves the item pending with no cost lock and no event; reopening trigger: a consumer that reads the request instead of the item. A `ceo` or `owner` may approve their own request; reopening trigger: an owner separation-of-duties policy. The RPC's requester-`cancelled` branch is unreachable because the item guard charges APPROVE_FINANCE; reopening trigger: a requester-cancel requirement. |
   ```

   The resulting file's Git blob is 196c55813a8c1afcccf01ca4d3b293d1c00538f1.

5. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, with Steps 1–4 applied and uncommitted in the main checkout, run with the project-local CLI and record, with actual counts, exits and exact SHA-256 values:
   - the SHA-256, md5 and byte counts of the migration and test 159, which must equal Consumer Closure;
   - on the local stack holding the migration: the guard's `md5(prosrc)`, security mode and ACL, the trigger and the index; test 159 and tests 20, 29, 88 and 115 alone; the races; mutants M1 and M2, each restoration proven equal;
   - the causal negative on a local stack without the migration, then the stack restored with it;
   - the local structural fingerprints of `scripts/parity_surface.sql`, before and after the migration;
   - the API-contract and map generators, the scope check and `git diff --check`.

   Treat as expected at this boundary only: an undeployed Primary and the seven measured-state items of Consumer Closure.

   Read a fresh Primary baseline, read-only: the project URL, the full ordered ledger and the absence of the target migration; the function and structural surfaces; the triggers and indexes of `approval_requests` and the absence of the guard function; the tenant and approval-request counts and the groups of more than one pending `finance_execution_approval` per `booking_item_id`, which must be 0. Record the predicted delta. If any reading differs, stop.
6. **Check** that an exact-SHA Gate-2 record for the migration is in the Execution Log: the owner's own, or one marked DELEGATED naming this contract, the migration's SHA-256, Primary `vrvtsxexkiiiivlkdxzp` and the owner's instructions under which it is taken. If absent, write it only when Step 5 passed and those instructions cover a migration that drops no table or column and deletes or rewrites no business row; otherwise stop after Step 5 and present the Gate-2 package.
7. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261109120000_a_decided_approval_is_final`. If it is absent and Step 6 is recorded:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts, the pending-duplicate groups and the triggers and indexes of `approval_requests`.
   - On an exact match, prove the transmitted text's md5 server-side, then apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row, its stored statement md5 equal to the file's, and no existing target version.
   - Read fresh: the ledger, the function surface and all ten structural surfaces; the triggers and indexes of `approval_requests`; the guard's `md5(prosrc)`, security mode and ACL; the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
8. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with the catalog figure `71/623` and the HTTP figure unchanged.
   - Confirm that `supabase/tests` holds 159 files whose literal `plan(N)` values sum to 3024, then set `Suite **159 files / 3024 assertions**`. If either differs, stop.
   - In each of the three rows AR-1, AR-2 and AR-3 of the register, replace the text `` | 🛡 | **FIXED 2026-11-09 locally (SPEC-299, `20261109120000`); Primary deployment pending.** `` with `` | ✅ | **✅ FIXED 2026-11-09 (SPEC-299, `20261109120000`), DEPLOYED to Primary under the exact-SHA Gate-2 record of this contract; the fresh Primary ledger, functions and structure equal local.** `` (each span's one leading and one trailing space are delimiters, not text), and change nothing else in the register.
   - Regenerate `MASTER_API_CONTRACT.md`, `ai-map.json` and `repository-index.md` (stored LF) with the canonical generators.
   - Run the four `scripts/test_*_guard.ps1` and require each to pass.
   - Set the Runtime Checkpoint to DONE, append the Execution Log, and commit the implementation once; the pre-commit Gate must admit it.

   If Primary is unproven, stop.
9. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `-Finish` through `scripts/run_timed.ps1`, watched by `scripts/watch_run.ps1`, and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, in the Complete commit: transition to Complete, tick the Acceptance Criteria and the Review Gate, clear `Active Change Request`, set `Last Completed` from Notes, leave `Next capability` and `Current Module` unchanged, and regenerate `ai-map.json` and `repository-index.md` LF.
   - Bind the exact candidate with `-Gate -BindCandidate`. Publication and promotion follow the native release path separately.

## Acceptance Criteria

- [ ] The migration is the frozen bytes; `check: blob supabase/migrations/20261109120000_a_decided_approval_is_final.sql 0fb6b37c21d7386e97794e144e30099e9807b825`
- [ ] Test 159 is the frozen bytes; `check: blob supabase/tests/159_a_decided_approval_is_final_test.sql 282d80dcc2f126e7a2ff9e13ed6a37ef4b5b5e74`
- [ ] The disposition record carries `approval_requests` AUDITED / ADVERSARIAL and coverage 45 of 78; `check: blob reports/master/MASTER_SURFACE_DISPOSITION.md 196c55813a8c1afcccf01ca4d3b293d1c00538f1`
- [ ] AR-1 to AR-3 are fixed and deployed in the register; `check: has reports/master/MASTER_GAP_REGISTER.md "DEPLOYED to Primary under the exact-SHA Gate-2 record of this contract"`
- [ ] The manifest suite figure equals the files; `check: has _ORVION_CANONICAL/manifest.md "Suite **159 files / 3024 assertions**"`
- [ ] Native evaluator remains exact; `check: same scripts/check_agent_continuity.ps1 @a4fc1e18685e5fbdb85eb6c5c1e6c82e7e023131`
- [ ] The originating review RPC migration remains exact; `check: same supabase/migrations/202607046100_review_finance_approval.sql @a4fc1e18685e5fbdb85eb6c5c1e6c82e7e023131`
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write, after a recorded Step 5 readiness gate and Step 6 Gate-2 record; Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] Mutants M1 and M2 are each killed with installation and restoration proven, and the causal negative is recorded.

## Execution Log

None.

## Verification Notes

None.


### 2026-11-09 — Gate 1 approval recorded

DELEGATED exact Gate1 under the owner's instructions of 2026-11-08 (class authorization for Batch 6 releases and standing approval of proposals ~10:20 Cairo; publish, promote and hosted deploy ~12:05 Cairo) and 2026-11-09 (slice 2 alongside WS-034 ~13:13 Cairo; go with the recommendation ~14:00 Cairo); Draft SHA-256 0EA381A46A2E41FFBED73115CF23577026150DCF34FD3EED091029211D663048, decision SHA-256 CAAF480EBFFD65AC4D382B2674B7A634E1E2377A387BBAE1A37D52EDE1291AC0. No fabricated human future-digest approval. Gate 2 (Primary deploy) is a separate exact-SHA record in Step 6. Immediately before allocation the hash, the Draft blob 0e7a43c23b33a8677763aef6db5e4d7e87a1ebae, all 2 source anchors, the baseline HEAD a4fc1e18685e5fbdb85eb6c5c1e6c82e7e023131 against refreshed origin/main a4fc1e18685e5fbdb85eb6c5c1e6c82e7e023131 and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 65e124b. No implementation performed before this transition.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

After actual native Finish and truthful Review, synchronize only this contract and the declared manifest/discovery paths to Complete. Set `Last Completed: **SPEC-299: Batch 6 Slice 44 — a decided approval request is final (AR-1, AR-2, AR-3), deployed to Primary; native verification and Review complete. Publication/promotion remain separately governed.**` and regenerate discovery. `Next capability` and `Current Module` stay unchanged: the selector names the next slice. Candidate binding follows Complete and is never a pre-Complete criterion.

Exact baseline a4fc1e18685e5fbdb85eb6c5c1e6c82e7e023131 and source anchors:

| Path | Baseline Git blob |
| --- | --- |
| `reports/master/MASTER_GAP_REGISTER.md` | `f6fc0dbeda8138a4d9662de1758ee956d1829621` |
| `reports/master/MASTER_SURFACE_DISPOSITION.md` | `f42ec9a678d708545b7aa4d25e46249c146a9a82` |

Selection sources: native AGENTS.md, CR_LIFECYCLE.md, ENGINEERING_METHOD.md and SPEC-298 at a4fc1e18685e5fbdb85eb6c5c1e6c82e7e023131; the owner's instructions of 2026-11-08 and 2026-11-09 (recorded outside this repository). Three identified snapshots and selection reasons are retained externally; correctness remains native and independent.

Snapshot identities: V1 0C094527E6018E41A7B8631A292544D7D3A6BEDD13F673BD6B6772064E76E672; V2 2C1BE3F14026D205C4EB7917F88548FC471DC0B425BC08534664F5B24750A8FF. V3 adds this linkage and the final selection; its own SHA-256 is external.
