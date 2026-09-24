# Change Request — SPEC-214

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make the `public.quotations` table door refuse every quotation state and commercial term that `app.create_quotation` and `app.advance_quotation` cannot produce — a quotation born outside `draft`, a quotation born with a non-zero total, a change to its customer or currency, a change to its total by anyone but the item-recompute path, and a send with no items — while every RPC, the item-recompute path and the customer-merge path keep working exactly as they do today.

## Business Reason

Batch 6 Slice 14 selected `quotations` by measurement (`scripts/batch6_select_target.ps1` at `795d6bc`: Exposure **14**, first; `suppliers` second at 13). `authenticated` holds table-level INSERT and UPDATE on `quotations`, and the door enforced the transition AUTHORITY (`app.enforce_status_transition`, BEFORE UPDATE only) and none of the lifecycle STATE the two RPCs maintain. Four defects reproduced against the clean local stack, each in one rolled-back transaction, recorded here as:

- **QUO-5 (High)** — ENTRY-1's class, third instance. An `employee` holding CREATE_QUOTATION and explicit DENY overrides on SEND_QUOTATION and ACCEPT_QUOTATION inserted a quotation born `accepted`, with **0** items, no `sent_at`/`accepted_at` and **0** events, and `app.create_booking` then produced a booking from it. The same user asserting the same acceptance by UPDATE was refused `42501 permission denied: ACCEPT_QUOTATION`, so the gap is the INSERT door alone. Canon 26 makes `draft` the initial state and requires a `quotation_accepted` event whenever a quotation is accepted.
- **QUO-6 (High)** — the commercial terms of an offer that had left the building were rewritable. A SENT quotation was re-pointed from customer d1 to d2, accepted, and `app.create_booking` produced the booking **for d2**, a customer the offer was never sent to. An ACCEPTED quotation priced in EGP was re-denominated to SAR while its lines stayed EGP, and the `quotation_accepted` event recorded the forged currency.
- **QUO-7 (Medium)** — QUO-1's header half. QUO-1 made the total follow its lines from the ITEM side; the header was still writable directly: `total_amount = 1` stood against 10,000 of lines on a draft and on a SENT quotation, and `app.advance_quotation` copied the forged figure into the `quotation_sent` event payload. A draft could also be BORN with a total of 50,000 and no lines.
- **QUO-8 (Low)** — `app.advance_quotation` refuses to send a quotation with no items; a SEND_QUOTATION holder sent an empty draft directly.

## Risks

- **Breaking a legitimate writer is the main risk.** Three paths write `quotations` besides the two RPCs: `app.recompute_quotation_total` (SECURITY DEFINER, owner `postgres`, the only thing that keeps the total true), `app.merge_customer_identity` (SECURITY DEFINER, owner `postgres`, must re-point every customer referrer) and ordinary direct edits of fields no RPC owns (`valid_until`). The guard is SECURITY INVOKER so `current_user` names the caller and admits `postgres` — `app.guard_invoice_integrity`'s shape. Measured on the prototype: the recompute path moves the header (new file assertions 7-9), the real merge re-points a quotation (`111_customer_surface_test.sql` passes unchanged), and a `valid_until` edit and a direct send of a draft WITH lines both still work.
- **Narrowing a door that tests pin.** Twenty-nine existing files name `quotations`, `quotation_items` or `merge_customer_identity`; with the prototype installed every one passed with identical counts, and the whole suite passed (119 files, 1974 assertions, 0 failures) before and after the six HTTP suites.
- **Primary deployment is irreversible** and is gated by an explicit owner authorization inside Step 6, not by this contract's approval alone.
- Not repairing leaves a user who is explicitly denied acceptance able to manufacture an accepted quotation and a booking from it, and any CREATE_QUOTATION holder able to move a sent offer to another customer or currency.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-214-quotation-door-parity.md`
- `supabase/migrations/20260924120000_quotation_door_parity.sql`
- `supabase/tests/120_quotation_door_parity_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607049500_quotation_workflow.sql`
- `supabase/migrations/202607057600_a_quotation_total_is_the_sum_of_its_items.sql`
- `supabase/migrations/202607059000_a_quotation_that_left_the_building_is_not_a_draft.sql`
- `supabase/migrations/202607059400_the_parents_state_is_a_rule_on_every_door.sql`
- `supabase/migrations/202607062000_an_invoice_that_could_be_rewritten_after_it_was_issued.sql`
- `supabase/migrations/20260909130000_a_quotation_total_is_never_below_zero.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/39_employee_day_one_workflow_test.sql`
- `supabase/tests/56_financial_write_capability_test.sql`
- `supabase/tests/73_quotation_total_derivation_test.sql`
- `supabase/tests/84_quotation_line_integrity_test.sql`
- `supabase/tests/88_parent_state_on_every_door_test.sql`
- `supabase/tests/100_notification_delivery_lifecycle_test.sql`
- `supabase/tests/111_customer_surface_test.sql`
- `supabase/tests/112_quotation_total_sign_rule_test.sql`
- `scripts/verify_database.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`
- `reports/README.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/26_state_machines.md`
- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `GOVERNANCE.md`

## Required Reading

- `reports/master/MASTER_SURFACE_DISPOSITION.md` — the `quotations` row and the Coverage section
- `reports/master/MASTER_GAP_REGISTER.md` — QUO-1 to QUO-4, ENTRY-1 (the class QUO-5 is the third instance of), ARCH-2, and the `CONV-6` row the new rows follow
- `supabase/migrations/202607062000_an_invoice_that_could_be_rewritten_after_it_was_issued.sql` — `app.guard_invoice_integrity`, the shape this guard copies
- `supabase/migrations/202607049500_quotation_workflow.sql` — `app.create_quotation` and `app.advance_quotation`, the rules copied
- `_ORVION_CANONICAL/26_state_machines.md` — the Quotation State Machine
- `ENGINEERING_METHOD.md §4` — the DATABASE protocol, and that Primary for this repository is only `vrvtsxexkiiiivlkdxzp`
- `reports/evidence/primary-ledger-evidence.json` — the current recorded Primary reading and its `read_query`

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
| a quotation can no longer be born outside `draft` or with a non-zero total | `app.create_quotation` (the only RPC that inserts) | UNAFFECTED | Inserts `draft` with the column default 0; new file assertion 2 calls it as the denied `employee` and it succeeds |
| same | `app.create_booking` and `app.guard_parent_state_allows_write` (both require `accepted`) | VERIFY | The forged acceptance that fed them is refused (4); a genuinely accepted quotation still produces a booking for its own customer (23-24) |
| a quotation's customer and currency can no longer change after creation | `app.merge_customer_identity` (SECURITY DEFINER, owner `postgres`) | VERIFY | Admitted as `postgres`; `111_customer_surface_test.sql` calls the real merge and asserts the quotation re-pointed — passed with the prototype installed |
| same | `app.create_booking`'s customer-match rule; `app.add_quotation_item` (stamps each line with the header's currency) | VERIFY | Customer and currency are now what the lines and the booking were built on (17, 22, 24) |
| the header total can no longer be changed by a signed-in caller | `app.recompute_quotation_total` (SECURITY DEFINER, owner `postgres`, the only maintainer) | VERIFY | Admitted as `postgres`; RPC and direct lines both move the header (7-9); `73_quotation_total_derivation_test.sql` and `112_quotation_total_sign_rule_test.sql` pass unchanged |
| same | `app.advance_quotation` (copies `total_amount` and `currency_code` into the event payload) | UNAFFECTED | Never writes either column; the values it copies can no longer be forged |
| a send now requires at least one item on the table door | `app.advance_quotation` | UNAFFECTED | Already refuses the same case with the same words (14); its own send of a quotation with lines passes (15) |
| same | direct transitions by a SEND_QUOTATION holder | VERIFY | Sending a draft WITH lines directly still works (20) |
| any | `valid_until`, `lead_id`, owner and archive columns; `app.enforce_archive_authority`; `app.guard_write_capability`; `app.enforce_status_transition` | UNAFFECTED | Not named by the guard; `valid_until` edit passes (12); the transition authority still refuses the denied user (16) |
| any | `customer_timeline`, `lead_timeline`, `is_document_responsible`, `guard_quotation_item_parent_editable` (readers) | UNAFFECTED | Read only; they now read values the lifecycle produced |
| a new trigger and trigger function on `public.quotations` | the 29 existing pgTAP files naming `quotations`, `quotation_items` or `merge_customer_identity`, including `10_grant_model_test.sql`'s PUBLIC-EXECUTE class assertion | VERIFY | Identical counts with the prototype installed, 0 failures. A first draft without `revoke execute … from public` turned `10_…` #5 red; the revoke is part of Step 1 |
| same | the whole pgTAP suite | UNAFFECTED | 119 files, 1974 assertions, 0 failures on a clean reset with the prototype, and again after the six HTTP suites (Pass B) |
| same | `reports/master/MASTER_API_CONTRACT.md` (GENERATED, Check L3) | VERIFY | Regenerated from the prototype-installed stack into a scratch path: SHA-256 identical to the committed file. In Write Scope because the Gate derives it for any migration contract |
| same | `scripts/verify_database.sql` | UNAFFECTED | Against the prototype: `ALL CHECKS PASSED (77 tables, … 71/621 catalog …)` |
| same | the six HTTP suites in Additional Verification | VERIFY | Each exited 0 against the prototype-installed stack: 33, 120, 40, 74, 122 and 60 passed |
| migration set 220 → 221, function surface +1, structural surface | `reports/evidence/primary-ledger-evidence.json`; `_ORVION_CANONICAL/manifest.md` `Live state:` | WRITE | Rewritten from a post-deployment Primary read (GUARD-1), never from a repository list |
| pgTAP suite 119 → 120 files and its declared assertion total | `_ORVION_CANONICAL/manifest.md` `Live state:` (Check 15) | WRITE | Remeasured after the new file lands, never incremented on paper |
| findings QUO-5 to QUO-8; ENTRY-1's population | `reports/master/MASTER_GAP_REGISTER.md` | WRITE | Check 22 rejects a disposition row citing an unregistered id; ENTRY-1's row names ten open tables and this closes one |
| `quotations` disposition and coverage 14 → 15 of 77 | `reports/master/MASTER_SURFACE_DISPOSITION.md`; the manifest's `Batch 6 surface coverage` line | WRITE | Check 22 recomputes the Coverage totals from the rows; Check 24 requires the cited file's `-- ATTACK-CLASSES:` line and a negative assertion |
| dated content added to both Master documents | Check 21 freshness headers | WRITE | Each document's `Last updated:` moves in the same step that adds its dated content |
| any | `scripts/batch6_select_target.ps1` | UNAFFECTED | Stores nothing and reads the disposition file; the row change removes this surface from its NOT-RECORDED candidates |
| any | `reports/README.md`; the manifest's `Narrative:` field | UNAFFECTED | No session report is written; this contract is the immutable evidence artifact, as `SPEC-213` did |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| pgTAP Pass A and Pass B, the six HTTP suites and `verify_database.sql` green on a clean reset that includes the migration | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Check 22 / Check 24 — disposition rows, Coverage totals, cited finding ids and the cited test file agree | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Check 21 — each Master document's `Last updated:` is not older than its newest dated content | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Check 9 / Check 19 — manifest migration figures and the recorded Primary ledger agree with the repository | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 9 |
| Check 15 — manifest declared assertion total equals the `plan(N)` sum | AFTER_IRREVERSIBLE_ACTION | Step 2 | Step 7 | Step 9 |
| Check 7 — `ai-map.json` live_state equals the manifest by value | BEFORE_COMPLETION | Step 7 | Step 8 | Step 9 |
| Check 5 — `_ORVION_CANONICAL/manifest.md` inside its 7000-character budget | BEFORE_COMPLETION | NONE | NONE | NONE |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: The house shape is reused verbatim — `app.guard_invoice_integrity` (SECURITY INVOKER, `current_user = 'postgres'` admits the definer paths, a draft-only entry arm, fixed identity columns, a total frozen against direct writes) — but no existing control on `quotations` expresses any of these rules. `app.enforce_status_transition` is BEFORE UPDATE only and authorizes transitions; it has no entry arm (ENTRY-1) and no preconditions. `app.guard_write_capability` charges the object-class permission, which the actor holds. `quotations_total_amount_nonneg_check` bounds the sign, not the source. REVOKE was rejected because `app.create_quotation` and `app.advance_quotation` are SECURITY INVOKER and depend on the grants (the `trusted_devices` lesson). Column privileges were rejected because they cannot tell the RPC from the table when both run as the caller, and cannot express an entry state. Promoting ENTRY-1 into a shared entry-state representation in `app.status_transitions` was rejected under WORTH IT: it would change INSERT behaviour on ten further tables no slice has read, which ENTRY-1's own row forbids, while the entry rule here costs one `if` inside a guard the other three findings need anyway.

Added Property: a quotation's state and commercial terms are only ever what its lifecycle produced — born `draft` with a total of 0, customer and currency fixed at creation, the total moved only by the item-recompute path, and sent only with at least one item — on every door a signed-in caller can reach.

Causal Negative: reproduced against unmodified `795d6bc` on the local stack, in one rolled-back transaction: a denied `employee` inserted a quotation born `accepted` (0 items, 0 events) and `app.create_booking` produced a booking from it; the same user's UPDATE `sent → accepted` was refused `42501`. A SENT quotation's customer re-pointed d1 → d2 and the booking went to d2. An ACCEPTED EGP quotation became SAR with EGP lines. `total_amount = 1` against 10,000 of lines, copied into the `quotation_sent` payload. An empty draft sent directly by a SEND_QUOTATION holder.

Positive Test Design: the RPC creates a draft; a direct INSERT of an ordinary empty draft succeeds; the RPC and a direct INSERT both add lines and the header follows (10,500); a `valid_until` edit on a draft succeeds; the RPC sends a quotation with lines; rejected → draft through the RPC; a SEND_QUOTATION holder sends a draft WITH lines directly; the RPC accepts; a genuinely accepted quotation produces a booking for its own customer.

Negative Test Design: every refusal by this guard is SQLSTATE `23514` with the exact message from Step 1, and every actor is at `aal2` holding the permission the operation would otherwise need, so no permission, MFA or RLS control can be the refuser — the `employee` carries CREATE_QUOTATION with DENY on SEND_QUOTATION and ACCEPT_QUOTATION (every role holding the first holds the other two, so a deny is the only way to separate them), and the `branch_manager` holds all three. Refused: INSERT born `accepted`; INSERT born `sent`; INSERT of a draft with total 50,000; header total on a draft; currency on a draft; send of an empty draft; customer on a SENT quotation; total on a SENT quotation; currency on an ACCEPTED quotation. Contrast controls: the RPC refuses the empty send in the same words (`P0001`); the transition authority refuses the denied user's UPDATE `42501`; TENANT refusals are asserted from RLS (`42501`) and the composite FK (`23503`) with their exact messages, as the boundary this guard does not own.

Non-Empty Population Obligation: the BUSINESS assertion names the tenant's quotation-backed bookings by customer and number and requires exactly `…d1/Q120-G1`, so it cannot pass by selecting nothing; the closing residue assertion (no non-draft quotation without lines) is paired with the positive controls that created, sent and accepted a quotation with lines in the same tenant.

Mutation Obligation: each load-bearing predicate independently killed, against the migration's own text, inside one rolled-back transaction ahead of the new file's body — (M1) protection removed (no-op body): every guard refusal red; (M2) INSERT forgotten (`before update` only): 4, 5 and 6 red and none of 10, 11, 13, 17, 18, 22; (M3) UPDATE forgotten (`before insert` only): 10, 11, 13, 17, 18 and 22 red and none of 4, 5, 6; (M4) `postgres` admission removed: 7, 8 and 9 red (the recompute path refused); (M5) entry-state arm removed: 4 and 5 red; (M6) birth-total arm removed: 6 red; (M7) fixed-terms arm removed: 11, 17 and 22 red; (M8) total arm removed: 10 and 18 red; (M9) send-precondition arm removed: 13 red. The unmutated text turns none red. Plus the in-file control: dropping the trigger inside a savepoint admits the born-accepted INSERT (28), and the same INSERT is refused again after the rollback (29).

Post-Implementation Proof Obligation: `npx supabase test db` reports 0 failures and the assertions executed equal the sum of the literal `plan(N)` declarations across `supabase/tests`; the new file passes 30 of 30.

## Implementation Steps

1. **Check:** a file matching `supabase/migrations/20260924120000_*.sql` exists. If present, record Already Applied. Otherwise create `supabase/migrations/20260924120000_quotation_door_parity.sql` containing a leading comment block that names `SPEC-214 / QUO-5, QUO-6, QUO-7, QUO-8` and states the rule, followed by exactly these three statements and nothing else: (a) `create or replace function app.guard_quotation_integrity() returns trigger language plpgsql set search_path to ''` whose body, in this order: returns `new` when `current_user = 'postgres'`; on `INSERT` raises when `new.quotation_status_code is distinct from 'draft'` with the message `a quotation is created as a draft (canon 26); it cannot be created already % -- use app.advance_quotation` (the status), raises when `new.total_amount is distinct from 0` with the message `a quotation's total is the sum of its items and a new quotation has none; it cannot be created at %` (the total), and returns `new`; on `UPDATE` raises when `new.customer_id is distinct from old.customer_id or new.currency_code is distinct from old.currency_code` with the message `quotation % keeps the customer and currency it was created with; create a new quotation instead` (the old number), raises when `new.total_amount is distinct from old.total_amount` with the message `quotation % total is the sum of its items and is maintained by them; change the items instead` (the old number), raises when `new.quotation_status_code = 'sent' and old.quotation_status_code is distinct from 'sent'` and no `public.quotation_items` row has `quotation_id = new.id and tenant_id = new.tenant_id`, with the message `a quotation needs at least one item before it can be sent`, and returns `new` — every raise using SQLSTATE `23514`; (b) `revoke execute on function app.guard_quotation_integrity() from public;` (c) `create trigger quotations_guard_integrity before insert or update on public.quotations for each row execute function app.guard_quotation_integrity();`. The function must not be `security definer` and must carry no `auth.uid()` exemption; the migration must not change any grant, policy, index, constraint, other trigger or RPC.

2. **Check:** `supabase/tests/120_quotation_door_parity_test.sql` exists. If present, record Already Applied. Otherwise create it in the `begin; select plan(30); … select * from finish(); rollback;` shape, carrying the line `-- ATTACK-CLASSES: AUTH DOOR STATE BUSINESS TENANT PRIVILEGE CONCURRENCY=N/A REPLAY=N/A` with the reason for each `N/A` and for the undeclared INPUT and OBSERVABILITY stated in the header, and asserting in this order: 1 the `employee` actor holds CREATE_QUOTATION and not SEND_QUOTATION or ACCEPT_QUOTATION; 2-3 RPC create and a direct empty draft succeed; 4-6 born `accepted`, born `sent` and born with 50,000 refused; 7-9 RPC line, direct line, header equals 10,500; 10-11 header total and currency on a draft refused; 12 `valid_until` edit succeeds; 13 direct send of an empty draft refused; 14 the RPC refuses the same with `P0001` and the same message; 15 RPC send succeeds; 16 the denied user's direct `sent → accepted` refused `42501 permission denied: ACCEPT_QUOTATION`; 17-18 customer and total on the SENT quotation refused; 19 rejected → draft through the RPC; 20 direct send of the draft with lines succeeds; 21 RPC accept; 22 currency on the ACCEPTED quotation refused; 23 `app.create_booking` from it succeeds; 24 the tenant's only quotation-backed booking is for its own customer; 25 RLS refuses a draft planted in another tenant (`42501`, exact message); 26 the composite FK refuses another tenant's customer (`23503`, exact message); 27 the guard is SECURITY INVOKER, PUBLIC holds no EXECUTE, and exactly one trigger fires it BEFORE INSERT OR UPDATE; 28 with the trigger dropped inside a savepoint the born-accepted INSERT succeeds; 29 after the rollback the same INSERT is refused; 30 no non-draft quotation in the tenant is without lines. Every guard refusal asserts SQLSTATE `23514` and the exact message from Step 1. Actors are an `employee` with DENY overrides on SEND_QUOTATION and ACCEPT_QUOTATION and a `branch_manager`, both at `aal2`.

3. **Check:** `reports/master/MASTER_GAP_REGISTER.md` contains a row whose first cell is `QUO-5`. If present, record Already Applied. Otherwise insert, immediately after the `CONV-6` row and each separated by one blank line as the neighbouring rows are, four rows in the table's existing thirteen-column format: `QUO-5` (severity **High**, category `business invariant · state · authorization`), `QUO-6` (**High**, `financial integrity · business invariant`), `QUO-7` (**Medium**, `financial integrity`), `QUO-8` (**Low**, `business invariant · state`); each with a bold title stating the defect as this contract's Business Reason states it, `R`, batch `6`, `A`, `✅`, a status cell beginning `**✅ FIXED 2026-09-24 (SPEC-214, `20260924120000`).**` followed by that finding's measured reproduction from the Business Reason and the repair in one sentence, an EMPTY Owner Decision cell, source `SPEC-214`, added `09-24`, updated `09-24`. In the same step, in the `ENTRY-1` row only: immediately after the text `the class is now recorded and cannot be rediscovered as if new**` at the end of its status cell, insert one space followed by exactly the sentence quoted here between the ⟦ ⟧ marks (the marks themselves are not inserted): ⟦**2026-09-24 (SPEC-214): `quotations` closed by QUO-5, the third instance; nine tables remain. Promotion into `app.status_transitions` was weighed and declined — it would change INSERT behaviour on nine surfaces no slice has read, and here the entry rule is one arm of a guard three other findings needed.**⟧ — and change its Updated cell from `09-08` to `09-24`. Also prepend a new `Last updated: 2026-09-24 (…)` entry describing QUO-5 to QUO-8 and demote the current one to `Previously:` in the file's existing voice. Change no other row.

4. **Check:** `reports/master/MASTER_SURFACE_DISPOSITION.md`'s `quotations` row reads `NOT-RECORDED`. If it does not, record Already Applied. Otherwise set that row to disposition `PARTIAL`, assurance `ADVERSARIAL`, session `SPEC-214-quotation-door-parity`, findings `QUO-5, QUO-6, QUO-7, QUO-8`, and a Next cell stating that the table door's lifecycle state, commercial terms, authority contrast and tenant boundary were swept and QUO-5 to QUO-8 closed by `120_...`, and that four axes remain unclassified by choice: (1) event parity for direct-DML creation and transitions (canon 26's Required Events); (2) reassignment of `owner_user_id`, `lead_id` and `quotation_number` by any CREATE_QUOTATION holder who can see the row, which no RPC offers and canon does not decide (BOOK-9's question on another surface); (3) the `quotations` instance of ARCH-2 (a row born archived), reproduced in this slice and owned by ARCH-2's row; (4) direct writes to `sent_at`, `accepted_at` and `rejected_at`, probed and found to have no reader. Update the Coverage summary to `15 of 77 recorded · 6 `AUDITED` · 7 `AUDITED-OPEN` · 2 `PARTIAL` · 0 `EXEMPT` · 62 `NOT-RECORDED`` and its sentence to `All 15 recorded surfaces stand at `ADVERSARIAL``. In the same step, prepend a new `Last updated: 2026-09-24 (…)` entry for slice 14 and demote the current one to `Previously:`. Change no other row.

5. **Check:** the Execution Log contains an entry headed `Pre-deploy readiness gate`. If present, record Already Applied. Otherwise perform the gate and record every item's measured result in the Execution Log; the first item that does not hold is a STOP, and nothing is deployed while it stands:
   - a clean `npx supabase db reset` completed;
   - pgTAP **Pass A** (`npx supabase test db`) ran with 0 failures, and the assertions executed equal the `plan(N)` sum;
   - the six Additional Verification suites ran in the listed order, each exiting 0;
   - pgTAP **Pass B** ran after those suites with 0 failures;
   - `scripts/verify_database.sql` completed with `ALL CHECKS PASSED`;
   - the nine mutants of the Mutation Obligation were each applied to the text of Step 1's migration inside one rolled-back transaction ahead of Step 2's file body, against the clean-reset stack, and each turned red the assertions this contract names for it; the unmutated text turned none red;
   - `pwsh -NoProfile -File scripts/generate-api-contract.ps1` regenerates `reports/master/MASTER_API_CONTRACT.md` byte-identically;
   - `git status --porcelain` shows no path outside this contract's Write Scope;
   - `supabase/migrations/` contains exactly one migration absent from the recorded Primary ledger, and it is the file Step 1 created;
   - `pwsh -NoProfile -File scripts/check_repository_consistency.ps1` is run and its result recorded. Exactly three failure classes are admissible, all the same bounded undeployed state: `MIGRATION STATE DRIFT`; `SUITE FIGURE DRIFT`; and RECOVER-1 / Check 19 only when its `only in repository` set is exactly `20260924120000_quotation_door_parity` and its `only on Primary` set is empty. Any other failure is a STOP.

6. **Check:** `reports/evidence/primary-ledger-evidence.json`'s `ledger` array contains an entry beginning `20260924120000`. If present, record Already Applied. Otherwise, **first confirm that the owner has explicitly authorized Primary deployment of SPEC-214 after Step 5 was recorded, and record that authorization in the Execution Log; without it, set `Blocker:` to the owner gate and STOP here.** Then, in this order and stopping at the first step that does not hold: (a) confirm the target is project ref `vrvtsxexkiiiivlkdxzp` by reading it live through the `supabase-primary` connector, and that it is not Secondary `brplkqmbzffpxqgkkdzo`; (b) read Primary's migration ledger with the exact query recorded in the evidence file's `read_query`; (c) prove `20260924120000` is absent and the ledger equals the recorded evidence (same `migration_count` and `ledger_fingerprint`); (d) apply ONLY Step 1's migration through the connector's migration-apply call; (e) if the connector assigns its own version, normalise it in Primary's ledger to `20260924120000`, as already done for `20260923120000`; (f) re-read Primary's full ledger with the same query; (g) rewrite the evidence file from that post-deployment reading, including the function-surface and structural-surface hashes read FROM Primary; (h) prove repository, local and Primary hold the same migration identities; (i) run `pwsh -NoProfile -File scripts/check_database_parity_evidence.ps1` and record its result. If any post-deployment operation fails, STOP and report Primary's exact state as read; do not re-apply and do not author a corrective migration.

7. **Check:** `_ORVION_CANONICAL/manifest.md`'s `Batch 6 surface coverage` line reads `15 of 77`. If it does, record Already Applied. Otherwise, after Step 6, update by measurement only: set that line to `15 of 77` (fifteen at `ADVERSARIAL`); remeasure and rewrite every mutable figure in `Live state:` — migration count and latest identity, ledger fingerprint, function-surface hash and function count, structural-surface hash and object count, test-file count and declared assertion total, and the HTTP assertion total — from measurement, never by incrementing; set `Last Completed` to SPEC-214 REPLACING the SPEC-213 entry; and set `Next capability` to Batch 6 Slice 15 ranked by `scripts/batch6_select_target.ps1`, keeping the standing facts that follow it. Do not modify `Narrative:`. The `Live state:` sentence may claim Primary parity only if Step 6 read Primary and proved it.

8. **Check:** `ai-map.json`'s `live_state` copies of `Last Completed`, `Active Change Request` and `Next capability` equal the manifest's by value. If they agree, record Already Applied. Otherwise regenerate with `pwsh -NoProfile -File scripts/generate-ai-map.ps1` and normalise the file to LF before committing. Repeat after every commit in this lifecycle that changes the manifest, including Approve and Complete.

9. **Check:** the Execution Log contains an entry headed `Post-deploy verification`. If present, record Already Applied. Otherwise run `pwsh -NoProfile -File scripts/check_database_parity_evidence.ps1`, `pwsh -NoProfile -File scripts/check_primary_ledger.ps1` and `pwsh -NoProfile -File scripts/check_repository_consistency.ps1`, and record each exit code; all three must exit 0.

## Acceptance Criteria

- [x] `supabase/migrations/20260924120000_quotation_door_parity.sql` exists and contains exactly the function, the revoke and the trigger Step 1 names, with no `security definer`, no `auth.uid()` exemption, and no grant, policy, index, constraint, other-trigger or RPC change.
- [x] `public.quotations` carries exactly one trigger executing `app.guard_quotation_integrity`, firing `BEFORE INSERT OR UPDATE`, and `app.guard_quotation_integrity` grants no `EXECUTE` to `PUBLIC`.
- [x] `app.create_quotation`, `app.advance_quotation`, `app.recompute_quotation_total`, `app.merge_customer_identity`, every RLS policy and every grant on `public.quotations` are identical to their definitions at the start of this Change Request.
- [x] `supabase/tests/120_quotation_door_parity_test.sql` exists, declares `-- ATTACK-CLASSES:` from the closed vocabulary, plans 30, contains `throws_ok`, and contains the in-file mutation control that drops the trigger inside a savepoint.
- [x] Every guard refusal in that file asserts SQLSTATE `23514` and the exact message Step 1 names, and its signed-in actors are an `employee` carrying DENY overrides on SEND_QUOTATION and ACCEPT_QUOTATION and a `branch_manager`, both at `aal2`.
- [x] `npx supabase test db` reports 0 failures and the assertions executed equal the sum of the literal `plan(N)` declarations across `supabase/tests`.
- [x] The Execution Log records all nine mutants of the Mutation Obligation, each turning red the assertions this contract names for it, and the unmutated migration turning none red.
- [x] `reports/master/MASTER_API_CONTRACT.md` is byte-identical to its state at the start of this Change Request.
- [x] `reports/master/MASTER_GAP_REGISTER.md` carries `QUO-5`, `QUO-6`, `QUO-7` and `QUO-8` rows, each FIXED by SPEC-214 with an empty Owner Decision cell; the `ENTRY-1` row records the third instance and the declined promotion; and its `Last updated:` entry is dated 2026-09-24.
- [x] `reports/master/MASTER_SURFACE_DISPOSITION.md` records `quotations` as `PARTIAL` / `ADVERSARIAL` citing `SPEC-214-quotation-door-parity` and `QUO-5, QUO-6, QUO-7, QUO-8`, its Next cell names all four unclassified axes, and its Coverage summary reads 15 of 77 with two `PARTIAL`.
- [x] `reports/evidence/primary-ledger-evidence.json` names `project_ref` `vrvtsxexkiiiivlkdxzp`, contains `20260924120000` in its `ledger` array, and its `migration_count` and `ledger_fingerprint` are consistent with that array.
- [x] The repository migration filename set, the local migration set and the Primary ledger recorded in that evidence file contain the same migration identities.
- [x] `_ORVION_CANONICAL/manifest.md` records Batch 6 coverage as 15 of 77, names SPEC-214 as `Last Completed` in place of SPEC-213, names Batch 6 Slice 15 as `Next capability`, and writes every mutable `Live state:` figure from a post-deployment measurement.
- [x] `ai-map.json`'s live_state copies of `Last Completed`, `Active Change Request` and `Next capability` match the manifest by value, and the file is stored with LF line endings.
- [x] The Execution Log records the owner's explicit Primary deployment authorization before the deployment, and the pre-deploy readiness gate's measured result for every item.
- [x] No file outside this contract's Write Scope was created, modified or deleted.

## Execution Log

### 2026-09-24 — Steps 1-4

Outcome: Complete

Step results:
- Step 1: Applied — `supabase/migrations/20260924120000_quotation_door_parity.sql` created; SHA-256 `2ab982d1a98225a095ce2cd62226b9094ad6b1f9a94480e57c9cf616c36ff808`, equal to the prototype recorded in Notes. The function, the revoke and the trigger only; `security definer`, `auth.uid()`, grant, policy, index and constraint appear in comments alone.
- Step 2: Applied — `supabase/tests/120_quotation_door_parity_test.sql` created; SHA-256 `bbe12ba75e9c4a7bfea41558813067efbdc2d4d583f4beaca8c1b41616d9f6dc`, equal to the prototype; `plan(30)`.
- Step 3: Applied — `QUO-5`, `QUO-6`, `QUO-7`, `QUO-8` after `CONV-6`, each with an empty Owner Decision cell; the `ENTRY-1` sentence inserted after its anchor and its Updated cell set to `09-24`; `Last updated: 2026-09-24`, prior entry demoted to `Previously:`.
- Step 4: Applied — `quotations` `PARTIAL` / `ADVERSARIAL` citing `SPEC-214-quotation-door-parity` and QUO-5 to QUO-8, Next cell naming the four unclassified axes; Coverage 15 of 77, two `PARTIAL`, 62 `NOT-RECORDED`; `Last updated: 2026-09-24`.

Commits: none for Steps 1-4. They stand applied in the working tree and are committed together with the post-deployment steps, as SPEC-213 did, because the pre-commit hook runs repository consistency, which cannot be green while the migration is undeployed.
### 2026-09-24 — Pre-deploy readiness gate (Step 5)

Outcome: Blocked

Step results:
- Step 5: Applied — every item held:
  - clean `npx supabase db reset`: exit 0; the reset database's latest migration is `20260924120000` (221 applied) and it carries `quotations_guard_integrity`.
  - pgTAP **Pass A**: `Files=120, Tests=2004`, `Result: PASS`; the literal `plan(N)` sum across `supabase/tests` is **2004** over 120 files.
  - Additional Verification, in order, each exit 0: `verify_api_end_to_end` 33 passed, `verify_role_journeys` 120, `verify_care_journeys` 40, `verify_journey_branches` 74, `verify_lifecycle_branches` 122, `verify_storage_end_to_end` 60 — 449 in total, 0 failed.
  - pgTAP **Pass B** after those suites, no reset: `Files=120, Tests=2004`, `Result: PASS`.
  - `scripts/verify_database.sql`: `ALL CHECKS PASSED (77 tables, … 71/621 catalog …)`.
  - Mutants of Step 1's text, each in one rolled-back transaction ahead of Step 2's file body, read from the repository files: M0 unmutated 30/30, none red; M1 protection removed red 4,5,6,10,11,13,14,17,18,22,24,29,30 (every guard refusal); M2 INSERT forgotten red 4,5,6,27,29,30 and none of 10,11,13,17,18,22; M3 UPDATE forgotten red 10,11,13,14,17,18,22,24,27,30 and none of 4,5,6; M4 `postgres` admission removed red 7,8,9 (plus the cascade 15,16,19,20,21,23,24); M5 entry arm removed red 4,5 (+29,30); M6 birth-total arm removed red 6; M7 fixed-terms arm removed red 11,17,22 (+24); M8 total arm removed red 10,18; M9 send-precondition arm removed red 13 (+14,30). Identical to the pre-Approval measurement recorded in Notes. Trigger present after all ten runs.
  - `scripts/generate-api-contract.ps1`: `MASTER_API_CONTRACT.md` byte-identical — `git hash-object --no-filters` of the regenerated file equals the committed blob `7b125622c8fe48b8771c4e605b2b802f23e73560`.
  - `git status`: only the four Write Scope paths of Steps 1-4.
  - Exactly one migration absent from the recorded Primary ledger (evidence: `vrvtsxexkiiiivlkdxzp`, 220, `3ab05c984755ffbca5b44ba9557b83dd`): `20260924120000_quotation_door_parity`, SHA-256 `2ab982d1…f808`; nothing only on Primary.
  - `check_repository_consistency.ps1`: 6 issues, all three admissible classes and nothing else — `MIGRATION STATE DRIFT` (count 220→221, latest, fingerprint → `17d4e308e52b70cc2747527c9bb757ed`), `SUITE FIGURE DRIFT` (files 119→120, assertions 1974→2004), RECOVER-1 with `only in repository` exactly `20260924120000_quotation_door_parity` and no `only on Primary` set. Checks 20, 21, 22 and 24 clean.
- Step 6: Not started — the owner has not authorized Primary deployment.

Commits: this commit (contract synchronization only; Steps 1-4 remain in the working tree for the reason recorded in the previous entry).

Blocker: Step 6 requires the owner's explicit authorization to deploy `20260924120000_quotation_door_parity.sql` to Primary `vrvtsxexkiiiivlkdxzp`. The owner's instruction for this slice withholds it until the local proof is presented. Nothing has been sent to Primary and Secondary has not been contacted.

### 2026-09-24 — Step 6: owner authorization and pre-deployment preconditions

Outcome: Complete

- **Owner authorization**, given after Step 5 was recorded: continue SPEC-214 and "deploy the already-proven migration to Primary if all preconditions still hold", limited to `20260924120000_quotation_door_parity.sql` with SHA-256 `2ab982d1a98225a095ce2cd62226b9094ad6b1f9a94480e57c9cf616c36ff808`, target `vrvtsxexkiiiivlkdxzp`, from local HEAD `60450ba`; Secondary excluded.
- Local state re-verified before any Primary contact: HEAD `60450ba5048a102b7083065f3b26acf7f5b7f06d`, four commits ahead of `origin/main` = `orvion-preflight` = `795d6bc`; working tree exactly the four Step 1-4 paths; migration SHA-256 `2ab982d1…f808` and test SHA-256 `bbe12ba7…f6dc`, both LF; no stash.
- (a) Target read live through the `supabase-primary` connector: `https://vrvtsxexkiiiivlkdxzp.supabase.co` — Primary, not Secondary `brplkqmbzffpxqgkkdzo`.
- (b)(c) Primary ledger read before deployment with the recorded `read_query`: count **220**, fingerprint `3ab05c984755ffbca5b44ba9557b83dd`, latest `20260923120000`, `20260924120000` ABSENT; `quotations_guard_integrity` and `app.guard_quotation_integrity` absent — equal to the recorded evidence, so exactly one migration is pending.
### 2026-09-24 — Steps 6-9: Primary deployment and post-deploy verification

Outcome: Complete

Step results:
- Step 6: Applied — before writing, one Primary-only precondition was read: `app.recompute_quotation_total` and `app.merge_customer_identity` are SECURITY DEFINER owned by `postgres` on Primary as locally, so the guard's `current_user = 'postgres'` admission holds there. (d) `supabase-primary` `apply_migration` with the exact text of Step 1's file (SHA-256 `2ab982d1…f808`) and nothing else: success. (e) The connector assigned `20260924070315`; that one row was normalised to `20260924120000`. (f) Full ledger re-read with the recorded `read_query`: count **221**, fingerprint `17d4e308e52b70cc2747527c9bb757ed`, `20260924120000_quotation_door_parity` present once. (g) Function surface read FROM Primary with the Check L2/P2 expression: `5e3e7959400d6857756f7079b2624eee`, 300 functions; `scripts/parity_surface.sql`'s statement run on Primary: `_combined` `d639d3c61d761f14f70a77c7e5cdd350`, 3033 objects, and all ten per-surface hashes equal the local stack's. Evidence file rewritten from those readings; the 221-entry ledger array was admitted only after its ordered md5 equalled Primary's fingerprint. (h) Repository filenames, local ledger and Primary ledger are the same 221 identities. (i) `check_database_parity_evidence.ps1` first exited 1 on Check L5 alone — the manifest still published the pre-deployment hashes, which Step 7 exists to replace; P1, P2, P4 and L3 all matched.
- Step 7: Applied — remeasured and rewritten: 221 migrations, latest `20260924120000`, ledger `17d4e308…`, function surface `5e3e7959…` (300), structural surface `d639d3c6…` (3,033), 77 tables, 71/621 catalog, 8 reporting views, 79 client RPCs, suite 120 files / 2004 assertions, 449 HTTP assertions; coverage 15 of 77; `Last Completed` SPEC-214 replacing SPEC-213; `Next capability` Batch 6 Slice 15. Manifest 6747 characters. (A bare-LF line left by an earlier edit made the first rewrite drop one blank line; restored before any check ran.)
- Step 8: Applied — `ai-map.json` regenerated and stored LF.
- Step 9: Applied — Post-deploy verification: `check_database_parity_evidence.ps1` exit 0 (`DATABASE PARITY: CLEAN`; `PRIMARY PARITY EVIDENCE: CLEAN`), `check_primary_ledger.ps1` exit 0 (`RECOVER-1 LEDGER EVIDENCE: CLEAN`), `check_repository_consistency.ps1` exit 0 (`REPOSITORY CONSISTENCY: CLEAN`).

No second repair was needed or attempted. Secondary was not contacted.

Commits: this commit (Steps 1-9).
## Verification Notes

### 2026-09-24 — Review

Verdict: Confirmed Complete

Findings: re-checked against the live repository, the local stack and Primary, not against the Execution Log. No suite was rerun for Review: `-Finish` had just certified this exact tree (`LOCAL_CERTIFY: READY`, 371 s — reset, pgTAP Pass A, the six HTTP suites, Pass B, `verify_database.sql`, parity evidence, repository consistency, `git diff --check`, primary ledger).
- Files changed since `795d6bc`: exactly eight of the nine Write Scope paths; `MASTER_API_CONTRACT.md` did not need to change and its diff is empty. The only migration added is `20260924120000_quotation_door_parity.sql`, whose committed blob hashes to `2ab982d1…f808` — the authorized bytes — and which names no grant, policy, index, constraint, other trigger or RPC outside comments; so `create_quotation`, `advance_quotation`, `recompute_quotation_total`, `merge_customer_identity` and every policy and grant on `quotations` are as they were.
- Local catalog: exactly one trigger executes `app.guard_quotation_integrity`, `BEFORE INSERT OR UPDATE ON public.quotations`; the function is SECURITY INVOKER and `PUBLIC` holds no `EXECUTE`. Primary's structural surface equals local's on all ten surfaces (`_combined` `d639d3c6…`, 3033), so the same holds there.
- `120_…`: declares `-- ATTACK-CLASSES:` from the closed vocabulary, plans 30, carries 14 `throws_ok`, of which the 10 guard refusals assert `23514` with the exact Step 1 messages; all 7 session claims are `aal2`; actors are an `employee` with DENY overrides and a `branch_manager`; the savepoint mutation control drops the trigger. Assertions executed equal the plan sum: pg_prove fails any file whose plan is not met and `-Finish` passed both runs, Check 15 is clean at 2004, and Step 5 measured 2004 = 2004 on the same bytes.
- Register: QUO-5 (High), QUO-6 (High), QUO-7 (Medium), QUO-8 (Low), each FIXED by SPEC-214 with an empty Owner Decision cell; ENTRY-1 records the third instance and the declined promotion, Updated `09-24`; `Last updated: 2026-09-24`. Disposition: `quotations` `PARTIAL` / `ADVERSARIAL`, the four unclassified axes named; Coverage 15 of 77 with two `PARTIAL`.
- Evidence file names `vrvtsxexkiiiivlkdxzp`, holds 221 identities including `20260924120000`, count and fingerprint consistent (`check_primary_ledger.ps1` CLEAN), equal to the repository and local sets. The manifest publishes 15 of 77, SPEC-214 as `Last Completed`, Slice 15 as `Next capability` and the post-deployment figures; `ai-map.json` agrees (Check 7 clean) and is stored LF.
- Observation, not a defect and not acted on: Step 5's readiness gate and `-Finish` each run the same ~6-minute database protocol, and between them no migration or test byte changed (hash-proven). They sit on opposite sides of the irreversible Primary write and certify different trees, and reusing one for the other would need an evidence cache in the control plane — rejected under WORTH IT for this slice.

Recommendation to human: Set Status to Complete

## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as
      Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created, or deleted.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's
      Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

Evidence gathered before this contract was frozen, all local, synthetic and rolled back unless stated. The reproduction ran at `795d6bc` against the migration set `20260923120000`. The candidate was then installed on the local stack for the suite runs, and the stack was reset to the repository afterwards.

- **Prototypes, LF line endings** (provenance only; they live outside the repository, so no step depends on reproducing their bytes): migration SHA-256 `2ab982d1a98225a095ce2cd62226b9094ad6b1f9a94480e57c9cf616c36ff808`; test SHA-256 `bbe12ba75e9c4a7bfea41558813067efbdc2d4d583f4beaca8c1b41616d9f6dc`. The new file passed 30/30 on a clean reset, and again after the HTTP suites.
- **Differential and whole suite:** 29 files naming `quotations`, `quotation_items` or `merge_customer_identity` all passed with the candidate installed. The whole suite passed on a clean reset (119 files, 1974 tests), and again after the six HTTP suites (Pass B). The first full run failed 3 assertions of `100_notification_delivery_lifecycle_test.sql`. The same 3 failed with the candidate REMOVED: 98 `pending` notification deliveries had been left on the local stack by earlier HTTP runs without a reset. After a clean reset and one round of HTTP suites, only 2 remained. This is local-stack residue unrelated to quotations and is not addressed here.
- **Mutants**, measured against the final text: M0 none red; M1 red 4,5,6,10,11,13,14,17,18,22,24,29,30; M2 red 4,5,6,27,29,30; M3 red 10,11,13,14,17,18,22,24,27,30; M4 red 7,8,9,15,16,19,20,21,23,24; M5 red 4,5,29,30; M6 red 6; M7 red 11,17,22,24; M8 red 10,18; M9 red 13,14,30. Every red set beyond a mutant's named assertions is a consequence of that same missing predicate. M4: the quotation never gets lines, so everything after it cascades. M7: the booking follows the re-pointed customer (24). M9: the empty quotation is already sent, so the RPC answers with a different refusal (14). 27 is the structural check on trigger timing. The trigger was present after all ten runs.
- **Generated and smoke surfaces:** `MASTER_API_CONTRACT.md` regenerated into a scratch path with the same SHA-256 as the committed file. `verify_database.sql` returned `ALL CHECKS PASSED`. The six HTTP suites exited 0: 33, 120, 40, 74, 122 and 60 passed.
- **A first draft was corrected by the evidence twice.** Without `revoke execute … from public` it turned `10_grant_model_test.sql` #5 red. It also carried the house `auth.uid() is null` exemption, which was removed when the mutant design showed it could never decide anything: `service_role` holds no INSERT or UPDATE on `quotations`, and every other session-less writer is `postgres`.

**Candidate selection**, recorded so it is not re-litigated. Four designs were weighed on one invariant: the table door may not produce what the lifecycle cannot. **A** (this contract) was prototyped and passed everything above. **B** (REVOKE) and **C** (column privileges) were rejected without being built, for the reasons in Existing Mechanism. **D** (promoting ENTRY-1) was rejected under WORTH IT.

**Deliberately not absorbed**, each named in the disposition row's Next cell and not registered, because none was classified in this slice: event parity for direct-DML creation and transitions; owner, lead and number reassignment; ARCH-2's `quotations` instance, which is already registered; and lifecycle timestamps with no reader.
