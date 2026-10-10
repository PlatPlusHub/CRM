# Change Request — SPEC-258

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Foundation Completion Programme Batch 6 Slice 36: give `public.quotation_items` a truthful disposition and close **QUO-9** and **QUO-10**.

The surface is canon 24's Quotation Item: one service line inside a quotation, recording its service type, quantity, unit price and currency. `authenticated` holds table-level INSERT, SELECT and UPDATE, and `app.add_quotation_item` is SECURITY INVOKER through that same grant, so PostgREST serves the table beside it. A quotation's total is defined as the sum of its line totals (QUO-1) and travels into the `quotation_sent` and `quotation_accepted` events.

After this change one invariant holds on both doors and for every caller: **a quotation line stays on the quotation it was added to, which must be a draft read under the lock `app.add_quotation_item` takes; it is priced in that quotation's currency; and its total is its own quantity times its own unit price, in the column's type.**

Record the surface `AUDITED`.

This contract does not touch any grant, policy, constraint, permission charge, state transition, canon document, other surface, n8n or any Phase-8 work.

## Business Reason

### Selection
`scripts/batch6_select_target.ps1`, recorded in SPEC-257's post-deploy certification at `5398ac0` (the schema `44c09d8` carries), ranks `quotation_items` first among the 42 surfaces still `NOT-RECORDED`: Exposure 8, coverage 36. The runner-up is `totp_enrollments` at 8/38.

### Authority
- **Canon 24 (Quotation Item):** a service line inside a quotation, recording service type, quantity, unit price and currency. **Canon 29:** a Quotation has many Quotation Items. **Canon 31:** `quotation_items` carries `quantity`, `unit_price`, `total_amount` and `currency_code`.
- **The sole sanctioned writer, `app.add_quotation_item`** (`202607059000`, as amended by `20260909130000`): it charges CREATE_QUOTATION, locks the quotation `for update`, refuses any status but `draft`, stamps the line with the quotation's currency, and writes `quantity * unit_price` as the line total. No RPC moves a line, re-labels its currency or edits it after creation.
- **QUO-1** (`202607057600`) defined the quotation total as the sum of its line totals, maintained by `app.recompute_quotation_total`. **QUO-2** (`202607059000`) made the table door refuse a line on a non-draft quotation, through `app.guard_quotation_item_parent_editable`. **QUO-6** and **QUO-7** (SPEC-214, `20260924120000`) fixed a quotation's currency for life and refused a hand-written quotation total. **MONEY-2** (`20260909130000`, owner decision 2026-09-09): a line total is never below zero, and a discount is represented explicitly, not by the line.

### QUO-9 (Medium) — a quotation line's total and currency were whatever the direct writer stated
Measured at `44c09d8` on the local stack in rolled-back transactions, by an `employee` proven first (`current_user`, `auth.uid()`) to hold CREATE_QUOTATION and SEND_QUOTATION, on quotations created and filled through the RPCs:
- A direct INSERT of a 100 x 1 line with `total_amount` 90000 took the quotation from 500 to **90,500**. A direct UPDATE of a 500 x 1 line's total to 1 took it to **1**, the line reading `500.0000x1.00=1.0000`.
- A direct INSERT of a USD line on an EGP quotation was summed into the EGP total (600 = 500 EGP + 100 USD). A direct UPDATE re-labelled an existing line SAR.
- A second employee carrying an explicit DENY on CREATE_QUOTATION, refused a price change (42501) and refused the RPC, set a line's total to 7, and the quotation followed to **7**: `app.guard_financial_capability` charges `unit_price` and `quantity` only, and the total moved without either.

The quotation total is what the customer is offered and what `app.advance_quotation` records in `quotation_sent` and `quotation_accepted`. A line total that is not its own arithmetic, or a sum across currencies, makes that figure false. It is QUO-1's and QUO-7's class one level down: Medium.

### QUO-10 (Medium) — a line could leave a sent quotation, or reach one while it was being sent
Measured at `44c09d8` by the same employee:
- After quotation 1 was sent through `app.advance_quotation` with its one 1,000 line, a direct UPDATE of that line's `quotation_id` moved it to a draft. The sent quotation was left with **0 lines and a total of 0** against its `quotation_sent` event of 1,000, and was then **accepted at 0** (`quotation_accepted` total 0). The editable-parent guard judged only the line's NEW quotation. The denied employee moved a line the same way.
- In two concurrent sessions, a direct INSERT read quotation `RACE-DIRECT` as `draft` while `app.advance_quotation` was sending it, waited on the send's lock (`pg_stat_activity` `wait_event_type = 'Lock'`), and then committed: the sent quotation held **2 lines and 1,300** against its `quotation_sent` event of 1,000. The RPC, run with the same timing against `RACE-RPC`, waited, re-read the quotation as `sent` and refused.

QUO-2 exists because a sent quotation's lines are the customer's offer. Both paths change that offer after it left, without any sanctioned writer: Medium, as QUO-2 was.

### Found while attacking the repair
The guard is SECURITY DEFINER and runs before RLS's WITH CHECK. On `44c09d8`, an employee naming another tenant's SENT quotation id was answered 23514 "a sent quotation cannot have its lines changed", where RLS would have refused: the guard disclosed a foreign quotation's state. The first draft of this repair would also have locked that row and named its currency. The repair reads only the signed-in caller's own tenant, so RLS is the refuser and nothing of the foreign row is reported.

### The repair
One migration replaces the body of `app.guard_quotation_item_parent_editable()`, which is already the row-level BEFORE INSERT OR UPDATE trigger `quotation_items_guard_parent_editable`, already SECURITY DEFINER with an empty `search_path`, owner `postgres` and ACL `{postgres=X}`. For every caller:
- On UPDATE it refuses a change of `quotation_id` (23514): no sanctioned writer moves a line.
- It reads the quotation `for update`, the lock `app.add_quotation_item` takes, by the row's tenant and id; for a signed-in caller only within `app.current_tenant_id()`. A quotation it cannot read is left to the foreign key and RLS, as before.
- It refuses any status but `draft` (23514), unchanged.
- It refuses a `currency_code` other than the quotation's (23514).
- It refuses a `total_amount` other than `quantity * unit_price` held in a variable of `public.quotation_items.total_amount%type`, so the product is rounded exactly as the RPC's stored product is (23514).

The function's comment is restated to name what it now holds. No table, column, grant, policy, constraint, trigger, permission, event type, catalog value or state transition is added or changed, and `app.add_quotation_item`, `app.advance_quotation` and `app.recompute_quotation_total` are unchanged.

### Rejected
- **Deriving the line total instead of refusing a wrong one:** a client's total would be silently replaced, and test 112's MONEY-2 table-door assertions 10 and 11, which write a negative total beside a non-negative price and expect a refusal, would then succeed. Refusing is what SPEC-214 chose for the quotation total (QUO-7).
- **Stamping the quotation's currency over the caller's:** a unit price stated in USD would silently become the same number in EGP. Refusing names the conflict.
- **A generated column for the total:** every writer that supplies `total_amount`, the RPC included, would fail, and the RPC would have to change. That is a larger change than the defect.
- **Charging CREATE_QUOTATION for `total_amount`, `currency_code` and `quotation_id` in `app.guard_financial_capability`:** an authorized caller could still misprice, mix currencies or move a line. The repair makes those writes impossible for everyone, which removes the denied employee's path with it.
- **Charging CREATE_QUOTATION for every UPDATE of a line:** see Held. It would change FIN-3's recorded rule for financial rows, beyond this slice.
- **A second trigger:** the existing guard already fires on both operations, already owns the line's parent rule, and already holds the definer rights the lock and the tenant read need.
- **Rounding `app.add_quotation_item`'s arguments to the column types:** see Risks. It would change a second function for inputs no client sends.

### Held, recorded so a later slice does not rediscover it
- **Capability:** a price or quantity change by the denied employee is charged CREATE_QUOTATION and refused (42501); the RPC refuses the denied employee.
- **Non-money edits:** the denied employee can still edit a draft line's description and service type. FIN-3 charges a financial row's money columns on UPDATE and leaves the rest to the authority already held, and the quotation header lets the same employee edit through SEND_QUOTATION. Pinned by test 150 assertion 20 as a boundary, not asserted as correct.
- **Tenant:** a row under another tenant is refused by RLS; the foreign keys are tenant-qualified; there is no DELETE grant.
- **Events:** canon 27 defines no quotation-line event; the quotation's own events carry its total.
- **`created_at`:** writable at the door and read by no function, view or policy in the repository. No consumer, so no finding.
- **Department scope:** QUO-4's resolved reading stands; `84_…` assertion 15 still lives.

## Risks

- **Changed INSERT and UPDATE semantics, for every caller.** A line whose total is not its quantity times its price, or whose currency is not its quotation's, is refused (23514). A line no longer moves between quotations. A client that changes a price must send the new total in the same statement, and a client that omits the total gets the column default 0, which is refused unless the price is 0. Every HTTP suite adds lines through the RPC, and every pgTAP fixture that writes a line directly already writes a consistent one: the whole suite passes unchanged on the prototype.
- **The RPC with over-precise arguments.** `app.add_quotation_item` multiplies its raw arguments, so a quantity with more than two decimals or a price with more than four is stored rounded beside an unrounded product: today quantity 1.555 at 100 is stored as 1.56 beside a total of 155.5, and 33.33335 x 3 as 33.3334 beside 100.0001. Those calls are now refused with 23514. Both HTTP callers send whole numbers (`verify_api_end_to_end.ps1` 18000 x 2; `verify_lifecycle_branches.ps1` 30000 and 24000).
- **Serialization.** A direct line write now waits for a concurrent send of the same quotation, and two direct line writes on one quotation serialize, as the RPC's do. The lock order is the RPC's (quotation, then line), and `app.advance_quotation` takes the same quotation lock first, so no new lock cycle is introduced.
- **Mechanism substitution.** Test 112 assertions 10 and 11 (a negative line total at the table door) now meet this guard before MONEY-2's line constraint, because each states a total other than its price times its quantity. Their claim still holds, the constraint stays as MONEY-2's structural rule (112 assertions 1–2), and no writer path remains on which the constraint alone would refuse. Test 84's QUO-2 assertions are refused by the same status arm as before.
- **Primary deployment** replaces one function body and its comment, and nothing else. It requires separate exact-byte owner authorization (Gate 2); approving this contract does not authorize it. Primary holds no quotations.
- **Workstation, not in scope:** resets for this contract run from the main checkout. A reset from a scratch git worktree leaves local storage without `bucketid_objname`.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-258-a-quotation-line-stays-on-its-quotation-at-its-own-price.md`
- `supabase/migrations/20261010140000_a_quotation_line_stays_on_its_quotation_at_its_own_price.sql`
- `supabase/tests/150_a_quotation_line_stays_on_its_quotation_at_its_own_price_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607057600_a_quotation_total_is_the_sum_of_its_items.sql`
- `supabase/migrations/202607059000_a_quotation_that_left_the_building_is_not_a_draft.sql`
- `supabase/migrations/20260909130000_a_quotation_total_is_never_below_zero.sql`
- `supabase/migrations/20260924120000_quotation_door_parity.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/56_financial_write_capability_test.sql`
- `supabase/tests/57_write_capability_map_test.sql`
- `supabase/tests/58_write_grants_and_config_capability_test.sql`
- `supabase/tests/68_financial_status_capability_test.sql`
- `supabase/tests/73_quotation_total_derivation_test.sql`
- `supabase/tests/83_actor_attribution_test.sql`
- `supabase/tests/84_quotation_line_integrity_test.sql`
- `supabase/tests/88_parent_state_on_every_door_test.sql`
- `supabase/tests/112_quotation_total_sign_rule_test.sql`
- `supabase/tests/120_quotation_door_parity_test.sql`
- `reports/architecture-decision-records.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/24_entity_registry.md`
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
- `_ORVION_CANONICAL/24_entity_registry.md` (Quotation Item); `_ORVION_CANONICAL/27_event_catalog.md` (Quotation Events); `_ORVION_CANONICAL/29_relationship_map.md` (Quotation To Quotation Item); `_ORVION_CANONICAL/31_schema_draft.md` (`quotation_items`)
- `reports/master/MASTER_GAP_REGISTER.md` (QUO-1 to QUO-8, MONEY-2, FIN-3, PARENT-1); `reports/master/MASTER_SURFACE_DISPOSITION.md`; `reports/master/MASTER_EXECUTION_PLAN.md` Batch 6 method and EC-1…EC-11
- `supabase/migrations/202607059000_a_quotation_that_left_the_building_is_not_a_draft.sql`; `supabase/migrations/20260909130000_a_quotation_total_is_never_below_zero.sql`; `supabase/migrations/20260924120000_quotation_door_parity.sql`
- Current local `app.add_quotation_item`, `app.advance_quotation`, `app.recompute_quotation_total`, `app.guard_quotation_item_parent_editable`, `app.guard_financial_capability`, `app.guard_quotation_integrity`
- Tests 73, 84, 112 and 120

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
- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A line's total is its quantity times its price, and its currency its quotation's, for every caller | `app.add_quotation_item`; `app.recompute_quotation_total`; `quotations.total_amount`; `quotation_sent` / `quotation_accepted` payloads | WRITE | The prototype was a scratch worktree at `44c09d8`, with the migration applied with its ledger row on a stack reset from the main checkout. Migration SHA-256 `663e759db30c6d594c08b9fae1fd6b8beb52fdcee42ff5ece0f74ab89270fd91`, md5 `0e7fbc0eb122af8a81106824b9b0ae2b`, 5900 bytes, 94 LF lines, ASCII. A 100 x 1 line at 90,000, the same line omitting its total, a 500 x 1 line rewritten to 1, a price changed without its total, a USD line on an EGP quotation and a line re-labelled SAR were each refused 23514, and the quotation stayed the sum of its lines. The RPC's 33.3333 x 1.5 line, stored as 50.0000, was accepted. |
| A line stays on its quotation, read under the RPC's lock | `app.advance_quotation`; `app.guard_quotation_integrity`; QUO-2's status rule | WRITE | A move between two drafts, a move out of a sent quotation, and a session-less move were refused 23514. The sent quotation kept its line, and `quotation_sent` and `quotation_accepted` both read 1,000. In two concurrent sessions the direct INSERT racing a send waited on the lock and was refused 23514 "a sent quotation cannot have its lines changed"; the quotation kept 1 line and 1,000. |
| The denied employee | `app.guard_financial_capability`; FIN-3 | VERIFY | Unchanged: the denied employee's price change is refused 42501. The total-only rewrite and the move are now refused 23514 by the guard, not by a new charge. A description edit still succeeds (test 150 assertion 20, pinned). |
| A foreign tenant's quotation | `scope_isolation` RLS | WRITE | An employee naming another tenant's SENT quotation is refused 42501 by RLS; on `44c09d8` the guard answered 23514 with that quotation's state. |
| QUO-2, QUO-4, QUO-1 and MONEY-2's assertions | tests 73, 84, 112, 120, 88 | VERIFY | Each passes unchanged on the prototype: 13/13, 17/17, 16/16, 30/30, 25/25. Test 112 assertions 10 and 11 now meet this guard first (Risks, Mechanism substitution). |
| Other tests reading this table or its guards | tests 03, 07, 08, 10, 54, 56, 57, 58, 68, 83 | VERIFY | Each passes unchanged on the prototype: 1/1, 2/2, 2/2, 9/9, 6/6, 12/12, 12/12, 27/27, 11/11, 23/23. |
| Test 150 | `supabase/tests` | WRITE | SHA-256 `9eea06b3756dbe3ded9d8f27946ae352e51f422cd9f3605f65623534b8cb582c`, `plan(33)`, 17925 bytes, 255 LF lines, ASCII: 33/33 on the prototype. With the pre-repair guard installed inside its own transaction, the causal negative below fails. |
| The generated API contract | `MASTER_API_CONTRACT.md` | WRITE | The canonical generator against the prototype reports 80 RPC endpoints (80 with HTTP evidence), 8 views and 74 tables and is byte-identical to the committed contract: no grant, table or client RPC moves. Step 7 regenerates it, and it stays unchanged. |
| Suite, HTTP and smoke | full pgTAP; the six HTTP suites; `scripts/verify_database.sql` | VERIFY | On the prototype, in `-Finish`'s order on a main-checkout reset: pgTAP Pass A 150 files / 2778 assertions PASS (2745 + 33); HTTP 35 + 40 + 85 + 122 + 122 + 60 = 464 passed, 0 failed; Pass B 150 / 2778 PASS; smoke `ALL CHECKS PASSED (78 tables, … 71/622 catalog, …)`; plan sum 150 / 2778. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | With the migration, the function surface becomes `b526e294da3ac335350d2ad3758971e4`/323 and the combined surface `2e608d8e6162a3a466583fe2bb327566`/3115. Triggers, policies, constraints, grants, columns, views, indexes, status transitions and RLS each equal the recorded Primary value. The 247-file ledger fingerprint is `f2fd129466f76536d53779a131cda874`. The guard stays SECURITY DEFINER, owner `postgres`, `search_path=""`, ACL `{postgres=X/postgres}`. |
| Measured state that moves | manifest (`Live state`, suite figure, coverage, Last Completed, Current Module, Next capability); `primary-ledger-evidence.json`; `ai-map.json` | WRITE | 246 → 247 migrations, latest `20261010140000`; 149 → 150 files and 2745 → 2778 assertions; coverage 36 → 37 of 78. HTTP (464), tables (78), catalog (71/622), views (8) and client RPCs (80) do not move. Primary values are written only from fresh post-deploy readings. |
| QUO-9 and QUO-10 fixed; the surface `AUDITED` | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24, 25 | WRITE | Test 150's `-- ATTACK-CLASSES:` line and negative assertions satisfy Check 24 for `quotation_items`. QUO-9's and QUO-10's Owner field is `—`, so Check 25 reads no owner decision. The coverage line becomes 16 `AUDITED` and 18 `AUDITED-OPEN`. Neither ENTRY-1 nor ARCH-2 names this table, which has no status or archive column. |
| Repository consistency | `scripts/check_repository_consistency.ps1` | VERIFY | On the prototype, exactly the pre-deploy measured-state drift: `manifest says 246 migrations, repository holds 247`; latest `20261010120000` vs `20261010140000`; ledger fingerprint `a6500a25…` vs `f2fd1294…`; `149 test files` vs 150; `2745 assertions` vs 2778; RECOVER-1 ledger evidence. Checks 21 to 28 are clean, and `git diff --check` is clean. These are not waived: Step 7 makes them true, and Step 8 requires them green. |
| CI-only guard self-tests | `scripts/test_*_guard.ps1` (four) | VERIFY | Not run on the prototype. Their documented pin is the manifest's open-decision enumeration, which this contract does not change, and on the prototype they could only report the drift above. Step 7 runs all four on the deployed state and requires each to pass. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused tests, pgTAP A/B, the six HTTP suites, smoke and mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| QUO-9, QUO-10 and the disposition describe the local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |
| The four CI-only guard self-tests pass | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `app.guard_quotation_item_parent_editable()` is already the line's row-level BEFORE INSERT OR UPDATE guard for every caller, already SECURITY DEFINER, and already owns the line's relation to its quotation (QUO-2). It judged only the new quotation's status, unlocked, and nothing judged the line's own total or currency: `app.guard_financial_capability` charges a permission for price and quantity, the CHECK constraints judge each column alone, and `app.recompute_quotation_total` sums whatever the lines hold. This contract extends that one guard and adds no trigger, function, constraint or framework.

Added Property: Through either door and for every caller, a quotation line stays on the quotation it was added to, which is a draft read under the lock `app.add_quotation_item` takes; its currency is that quotation's; and its total is its quantity times its unit price in the column's type. A signed-in caller naming another tenant's quotation is refused by RLS, and the guard reports nothing of that row.

Causal Negative: These are the pre-repair measurements in Business Reason, at `44c09d8`:
- a 100 x 1 line inserted at 90,000, the quotation following to 90,500;
- a 500 x 1 line's total rewritten to 1, the quotation following;
- a USD line summed into an EGP quotation, and a line re-labelled SAR;
- the denied employee's total-only rewrite to 7, and the denied employee's move;
- a sent quotation's only line moved out, the quotation accepted at 0 against a `quotation_sent` of 1,000;
- a direct INSERT racing a send, committed onto the sent quotation at 1,300;
- a foreign tenant's SENT quotation's state disclosed by 23514.

With the pre-repair guard installed inside test 150's own transaction, test 150 fails assertions 7, 8, 9, 11, 12, 13, 14, 15, 18, 19, 21, 23, 26, 27, 28, 29, 31, 32 and 33, each for its intended reason: no exception where 23514 was required, the foreign quotation answered 23514 where 42501 was required, the quotation's lines and totals forged, the accepted event at 0, quotation 3 holding lines, and the lock absent from the guard's text.

Positive Test Design: One tenant with one branch and department; `emp`, an employee, and `den`, an employee with an explicit DENY on CREATE_QUOTATION; one customer; a rival tenant with one SENT quotation in SAR. Positive controls:
- the actors are proven first (`current_user`, `auth.uid()`, the held and denied permissions);
- the RPC adds a 1,000 line, a 500 line and a 33.3333 x 1.5 line stored as 50.0000;
- a consistent direct INSERT lands, and a draft line repriced with its total is an ordinary edit;
- quotation 2 reads the sum of its lines before and after the refusals;
- quotation 1 is sent and accepted through the state machine, and both events read 1,000 against its 1,000 line.

Negative Test Design:
- **Total:** a stated total, an omitted total, a total-only UPDATE, and a price change without its total are refused 23514, signed in and session-less.
- **Currency:** a foreign-currency INSERT and a currency re-label are refused 23514.
- **Move:** a move between drafts, out of a sent quotation, by the denied employee and session-less is refused 23514.
- **Authority:** the denied employee's price change is refused 42501, and the total-only rewrite 23514.
- **Status:** a line added to a sent quotation is still refused 23514.
- **Tenant:** a line naming the rival tenant's SENT quotation is refused 42501 by RLS.
- **Partial writes:** quotation 3 holds no line after every refusal.
- **PAR-4:** with the guard's trigger dropped, a foreign-currency line at 90,000 lands; after the rollback the identical insert is refused again.

Non-Empty Population Obligation: One tenant, one branch and department, two placed users with their roles and one deny grant, one customer, three quotations with four lines, and a rival tenant with one quotation. Every write and refusal is counted by row or event; no zero-row operation satisfies an assertion.

Mutation Obligation: Out of file, record a surface: the md5 of the guard's source with the table's trigger definitions. For each mutant:
1. Install it inside test 150's own transaction and prove the surface differs.
2. Run test 150 and record the failing assertions.
3. Prove after the rollback that the surface equals the base.

A mutant whose installation is not proven is a harness error, never a kill.

| Mutant | Change | Expected to fail |
| --- | --- | --- |
| M1 | the move arm removed | 19, 21, 23, 26, 29, 33 |
| M2 | the currency arm removed | 12, 13, 14, 15 |
| M3 | the total arm removed | 7, 8, 9, 11, 14, 15, 18, 28, 33 |
| M4 | the total compared as a raw product, not in the column's type | 4, 6, 14, 15 |
| M5 | the quotation read without `for update` | 31 |
| M6 | the caller-tenant scope removed from the read | 27 |

M5 is also killed behaviourally out of file: installed and committed on the local stack, the two-session race again committed a second line onto the sent quotation (1,300, 2 lines); the frozen function was then restored and the surface proven equal to the base.

Prototype result: base surface `f794641305cca8b756af1516ae060060`. Every installation changed the surface, and every rollback returned it to the base. All six were killed, exactly as listed.

Post-Implementation Proof Obligation: All of the following, on the final bytes and through canonical `-Finish`:
- the focused test, a clean reset from the main checkout, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke;
- the out-of-file mutations M1–M6, the two-session race against the repaired guard, and the pre-repair causal negative;
- the generated artifacts, the four CI-only guard self-tests, repository consistency and `git diff --check`;
- fresh Primary evidence, parity evidence and the Primary ledger check.

## Implementation Steps

1. **Check** that `supabase/migrations/20261010140000_a_quotation_line_stays_on_its_quotation_at_its_own_price.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `663e759db30c6d594c08b9fae1fd6b8beb52fdcee42ff5ece0f74ab89270fd91`, md5 `0e7fbc0eb122af8a81106824b9b0ae2b`, 5900 bytes.
   - Its statements replace `app.guard_quotation_item_parent_editable()` with the guard above and restate its comment. A comment block precedes them, stating the authority and QUO-9's and QUO-10's measurements.
   - If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/150_a_quotation_line_stays_on_its_quotation_at_its_own_price_test.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `9eea06b3756dbe3ded9d8f27946ae352e51f422cd9f3605f65623534b8cb582c`, `select plan(33);`.
   - Its `-- ATTACK-CLASSES:` line reads `AUTH TENANT DOOR STATE INPUT BUSINESS CONCURRENCY OBSERVABILITY PRIVILEGE=N/A REPLAY=N/A`, with each `N/A` reason and the CONCURRENCY note in its header.
   - If the target exists with different bytes, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` already contains a `QUO-9` row. If not, make these edits and nothing else:
   - **Register:**
     - a 2026-10-10 Slice-36 freshness entry, with the previous one demoted to `Previously:`;
     - after QUO-8, a new row QUO-9 (Medium), FIXED by SPEC-258 locally with Primary pending and Cert `🛡`, with the measurements above;
     - a new row QUO-10 (Medium), FIXED by SPEC-258 locally with Primary pending and Cert `🛡`, with the measurements above and the foreign-tenant disclosure found while attacking the repair;
     - both rows with Owner `—` and this contract as session.
   - **Disposition:**
     - a freshness entry, with the previous one demoted;
     - coverage 37 of 78 (16 `AUDITED`, 18 `AUDITED-OPEN`, 3 `PARTIAL`, 41 `NOT-RECORDED`) and the "All 37" line;
     - the `quotation_items` row `AUDITED` / `ADVERSARIAL` / SPEC-258 / QUO-9, QUO-10, with its evidence and its swept non-defects.

   If a target carries content other than its `44c09d8` bytes, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 values:
   - a clean local reset from the main checkout; test 150 and the focused tests 03, 07, 08, 10, 54, 56, 57, 58, 68, 73, 83, 84, 88, 112 and 120;
   - pgTAP Pass A, all six HTTP suites, then pgTAP Pass B without reset; smoke and the plan sum;
   - the mutation evidence M1–M6, and the two-session race against the repaired guard;
   - the API-contract and map generators;
   - the scope check, `git diff --check` and repository consistency.

   Treat as expected at this boundary only:
   - an undeployed Primary;
   - the pre-deploy repository-consistency drift listed in Consumer Closure.

   Read a fresh Primary baseline, read-only:
   - the project URL, the full ordered ledger and the absence of the target migration;
   - the function and structural surfaces;
   - `quotation_items`' triggers; `app.guard_quotation_item_parent_editable`'s text md5, security mode, owner, configuration and ACL;
   - the tenant, quotation and quotation-line counts.

   Record the predicted delta.
5. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 4 and present the Gate-2 package. Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261010140000_a_quotation_line_stays_on_its_quotation_at_its_own_price`. If it is absent and deployment is separately authorized:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts, the table's triggers and the guard's md5.
   - On an exact match, prove the transmitted text's md5 server-side, then apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires:
     - exactly one new row;
     - its stored statement md5 equal to the file's;
     - no existing target version.
   - Read fresh:
     - the ledger, the function surface and all ten structural surfaces;
     - the table's triggers;
     - the guard's definition, comment, security mode, owner, configuration and ACL;
     - the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with 464 HTTP assertions last passed on the Step-4 date.
   - Confirm that `supabase/tests` holds 150 files whose literal `plan(N)` values sum to 2778, then set `Suite **150 files / 2778 assertions**`. If either differs, stop.
   - Set Batch 6 coverage to 37 of 78, all thirty-seven at `ADVERSARIAL`.
   - Mark QUO-9 and QUO-10 `DEPLOYED` with Cert `✅`, worded without a date beneath the register's freshness line.
   - Regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` (stored LF) with the canonical generators.
   - Run the four `scripts/test_*_guard.ps1` and require each to pass.
   - Set the Runtime Checkpoint to DONE.
   - Run `check_primary_ledger.ps1`, `check_database_parity_evidence.ps1`, repository consistency and `git diff --check`.

   If Primary is unproven, stop.
8. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion, under `## Verification Notes`. After `Verdict: Confirmed Complete`, do all of the following in the Complete commit:
     - transition to Complete and clear `Active Change Request`;
     - run `scripts/batch6_select_target.ps1` and record its Top-12;
     - set `Last Completed` to SPEC-258 / Slice 36;
     - set `Current Module` to Foundation Completion Programme Batch 6 resuming at Slice 37;
     - set `Next capability` to **Foundation Completion Programme — Batch 6 Slice 37**, naming the measured first target, followed by the existing Phase-8 order, closed-chapter and standing-fact sentences unchanged;
     - keep the manifest within 7000 characters;
     - regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate with `scripts/publish_candidate.ps1` and require exact-SHA candidate CI.
   - Promote the same accepted SHA, require main CI, and run `-Certify` for `REMOTE_CERTIFY: READY`.
   - Verify synchronized clean refs.

## Acceptance Criteria

- [ ] A line whose total is not its quantity times its unit price in the column's type, including one that omits its total, is refused 23514 on INSERT and UPDATE, signed in and session-less; the RPC's rounded product is accepted.
- [ ] A line whose currency is not its quotation's is refused 23514 on INSERT and UPDATE.
- [ ] No caller can change a line's `quotation_id` (23514); a sent quotation keeps its lines, and its `quotation_sent` and `quotation_accepted` events agree with them.
- [ ] A direct line write racing a send of the same quotation waits for it and is refused, as the RPC is; recorded in two sessions against the repaired guard.
- [ ] A signed-in caller naming another tenant's quotation is refused 42501 by RLS, and the guard reports nothing of that quotation.
- [ ] The held controls stay held: the denied employee's price change is refused 42501; a line on a sent quotation is refused 23514; the RPC and a consistent direct write still add lines to a draft.
- [ ] `app.guard_quotation_item_parent_editable` keeps its trigger, SECURITY DEFINER, owner `postgres`, `search_path=""` and ACL `{postgres=X}`; `app.add_quotation_item`, `app.advance_quotation` and `app.recompute_quotation_total` are unchanged.
- [ ] Mutants M1–M6 are each killed against test 150, with installation and restoration proven, and M5 also in two sessions. The causal negative is recorded.
- [ ] QUO-9 and QUO-10 are fixed and deployed in the register.
- [ ] `quotation_items` is `AUDITED` / `ADVERSARIAL` in the disposition record, and coverage is 37 of 78. No other surface's row changed.
- [ ] The migration and test 150 matched their frozen SHA-256 values when applied.
- [ ] Primary, the recorded evidence, the manifest (247 migrations; 150 files / 2778 assertions; 464 HTTP assertions), the API contract and `ai-map.json` agree, and the four CI-only guard self-tests and repository consistency pass.
- [ ] The manifest names Batch 6 Slice 37 and its measured target as the next capability, with no Active Change Request.
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-10-10 — Gate 1 approval and execution started

- **Authority:** the owner's SPEC-258 Gate 1 approval of 2026-10-10 for Draft `cb9573b0fbcd8163c901149563498adf02319c5f`, contract SHA-256 `9f1aff002a47b7d763bd260df9cbd2ee24b8e1b4c4f60babda0c573b43b3e14e`, covering QUO-9, QUO-10 and the foreign-tenant disclosure the contract documents. Verified before acting: HEAD was that commit, the working tree was clean, and the contract file and its committed blob both hash to that value. The frozen prototype files in the scratch worktree hash to migration `663e759db30c6d594c08b9fae1fd6b8beb52fdcee42ff5ece0f74ab89270fd91` and test 150 `9eea06b3756dbe3ded9d8f27946ae352e51f422cd9f3605f65623534b8cb582c`. Approval was committed at `0263b41`; its pre-commit Gate returned `APPROVAL_EVIDENCE: PASS`.
- **Preconditions:** the migration and test 150 are absent from the repository. The register, disposition record, API contract and Primary evidence file are unchanged since `44c09d8`.
- **Publication range:** before this commit, `origin/main..HEAD` held 2 commits with 0 merges and was 0 behind.
- **Correction to Consumer Closure's CI-only guard row.** The Draft said the four `scripts/test_*_guard.ps1` suites pin only the manifest's open-decision enumeration. That is incomplete, and the owner asked that it be checked. Read from the scripts:
  - `test_cold_start_state_guard.ps1` attacks Checks 10, 14, 16, 20 and 25, over the manifest and the register;
  - `test_future_date_guard.ps1` attacks Check 12, which reads every dated entry this contract adds;
  - `test_status_contradiction_guard.ps1` attacks Check 2 over the register and the disposition record;
  - `test_primary_ledger_guard.ps1` attacks RECOVER-1 over the evidence file and the migrations.

  Each reads a file this contract changes. Step 4 therefore also runs all four on the working tree with Steps 1–3 applied, so that a guard needing a file outside Write Scope is found before the irreversible step (SPEC-240's failure). Only the drift Step 7 removes may fail there. Step 7's run stays mandatory.
- **Precision against the existing RPC callers.** The owner asked that the precision behaviour be covered and tested against the existing callers. `app.add_quotation_item` is unchanged. Every existing caller passes a price and quantity within the columns' precision:
  - `verify_api_end_to_end.ps1` 18000 x 2;
  - `verify_lifecycle_branches.ps1` 30000 and 24000 at the default quantity;
  - tests 39, 73, 84, 88, 112 and 120, using whole-number prices (including 0) and quantities of 1.

  Test 150 assertion 4 pins an in-precision fractional line (33.3333 x 1.5, stored as 50.0000). All of these run in Step 4's suites. The over-precise refusal named in Risks is measured again on the canonical state at Step 4. No rounding or pricing rule is added: a value the columns can hold behaves exactly as before.
- **Worktrees.** Read-only inventory, nothing modified:
  - `wt251`'s three never-pushed scratch commits have no equivalent patch on `origin/main`.
  - `wt255` carries 4 modified files, and `C:\w234` 15, whose content differs from `origin/main`.
  - Unique work cannot be ruled out in any of the three, and all three stay untouched.
  - `owt/p2` is clean on a commit `origin/main` contains.
  - `wt258` holds only this contract's prototype bytes. Its results are prototype evidence, never certification.
- **No Primary write is authorized.** Gate 2 stands before Step 6. Secondary is never contacted.

### 2026-10-10 — Pre-deploy readiness gate (Steps 1–4)

- **Steps 1–3 applied exactly as frozen** in the working tree, uncommitted until after deployment:
  - migration `663e759db30c6d594c08b9fae1fd6b8beb52fdcee42ff5ece0f74ab89270fd91` (md5 `0e7fbc0eb122af8a81106824b9b0ae2b`, 5900 bytes, LF), copied byte-for-byte from the prototype;
  - test 150 `9eea06b3756dbe3ded9d8f27946ae352e51f422cd9f3605f65623534b8cb582c`;
  - the register's Slice-36 freshness entry and rows QUO-9 and QUO-10 (Medium, `M`, Cert `🛡`, Owner `—`) after QUO-8;
  - the disposition's freshness entry, coverage 37 of 78 (16 `AUDITED`, 18 `AUDITED-OPEN`, 3 `PARTIAL`, 41 `NOT-RECORDED`), "All 37", and the `quotation_items` row `AUDITED` / `ADVERSARIAL`. No other line of either file changed.
- **Clean baseline, from the main checkout.** `npx supabase db reset` (exit 0, 2.5 min) applied the migration through the canonical loader. The prototype state was gone: 0 tenants with the prototype fixture ids. Ledger 247, `f2fd129466f76536d53779a131cda874`, latest `20261010140000`. Every structural surface equals the prototype's: functions `b526e294da3ac335350d2ad3758971e4`/323, triggers `a46035c1…`/309, combined `2e608d8e6162a3a466583fe2bb327566`/3115. The guard reads prosrc md5 `94fbaa14ed2af00aa74dd1d89225138e`, SECURITY DEFINER, owner `postgres`, ACL `{postgres=X/postgres}`, `search_path=""`.
- **Focused tests, each passing in full:** 03 1/1, 07 2/2, 08 2/2, 10 9/9, 54 6/6, 56 12/12, 57 12/12, 58 27/27, 68 11/11, 73 13/13, 83 23/23, 84 17/17, 88 25/25, 112 16/16, 120 30/30, 150 33/33.
- **Suites, in `-Finish`'s order:**
  - pgTAP Pass A: `Files=150, Tests=2778`, `Result: PASS`;
  - HTTP: 35 + 40 + 85 + 122 + 122 + 60 = 464 passed, 0 failed;
  - pgTAP Pass B, without reset: 150 / 2778 PASS;
  - smoke: `ALL CHECKS PASSED (78 tables, … 71/622 catalog, …)`;
  - plan sum 150 files / 2778.
- **Mutation evidence, on the committed-path bytes:** base surface `f794641305cca8b756af1516ae060060`. M1–M6 each installed (surface changed) and restored (surface equal to base), failing exactly 19,21,23,26,29,33 / 12,13,14,15 / 7,8,9,11,14,15,18,28,33 / 4,6,14,15 / 31 / 27.
- **Two sessions against the canonically applied guard:** a direct INSERT racing a send waited (`pg_stat_activity` `waiting=1`), then was refused 23514 "a sent quotation cannot have its lines changed". The quotation stayed `sent` with 1 line, 1,000, and a `quotation_sent` of 1,000. The first attempt in the run's script invoked WSL's `bash`, which has no distribution, and did not run. It was rerun through Git Bash, and this is that result.
- **Precision, measured on the canonical state (rolled back):**
  - quantity 1.555 at 100 through the RPC is refused 23514, "(156.0000); it cannot be 155.5000";
  - 33.33335 x 3 is refused, "(100.0002); it cannot be 100.0001";
  - test 112's two table-door shapes are refused by the guard's total arm, "(0.0000); it cannot be -900.0000" and "(1000.0000); it cannot be -1.0000".

  Every existing caller listed in the Gate-1 entry passed in the suites above.
- **Generated artifacts:** the API-contract generator, written to a scratch file, is byte-identical to the committed contract (`d28fb5672ca9c0795a99a74746069c973e1392edcc5e3d2a5a315348138175fd`): 80 RPC endpoints, 8 views, 74 tables. `ai-map.json`, stored LF, changes only its `generated_at`.
- **Scope:** `origin/main..` plus untracked touches exactly the manifest, `ai-map.json`, this contract, the register, the disposition record, the migration and test 150, all in Write Scope. `git diff --check` exit 0.
- **Repository consistency:** exactly the expected pre-deploy drift:
  - 246 vs 247 migrations;
  - latest `20261010120000` vs `20261010140000`;
  - fingerprint `a6500a25…` vs `f2fd1294…`;
  - 149 vs 150 files and 2745 vs 2778 assertions;
  - RECOVER-1 (2 issues): 6 issues in all.

  Checks 21–28 are clean.
- **The four CI-only guard self-tests, run on this working tree as the Gate-1 entry committed:**
  - `test_future_date_guard` passed (exit 0, 3.7 min);
  - `test_status_contradiction_guard` passed (exit 0, 3.7 min);
  - `test_primary_ledger_guard` failed only its two CONTROL cases (0.3 min);
  - `test_cold_start_state_guard` failed only its nine CONTROL, second-direction CONTROL and restore cases (A2, C2 and E CONTROL; A-, B-, C- and D-restore; 5.4 min).

  Each failing case requires an untouched copy of the repository to be CLEAN, which the drift above prevents until Step 7. Every mutation case passed. No guard needs a file outside Write Scope.
- **Fresh Primary baseline, read-only (`vrvtsxexkiiiivlkdxzp`, URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`):**
  - ledger 246, `a6500a25aeb035493ac37f18cb46fb32`, latest `20261010120000`; no row for the target version or name, and none after `20261010120000`;
  - functions `e3d5180863b8482178efde66465a47b4`/323;
  - `parity_surface.sql`'s ten surfaces equal the recorded evidence: combined `f56111d6426fb29d91ff6cb41ce1ada2`/3115;
  - `quotation_items` carries its five triggers, all enabled: `enforce_catalog_codes` 23, `enforce_subscription_write_gate` 31, `guard_financial_capability` 23, `guard_parent_editable` 23, `recompute_total` 29;
  - the guard: prosrc md5 `671c776f138de165d6f2e89a59183d63` (definition `f2b1fac44aa750a76cb79b92a1bdba04`), SECURITY DEFINER, owner `postgres`, ACL `{postgres=X/postgres}`, `search_path=""`, comment `QUO-2: …`;
  - 0 tenants, 0 quotations, 0 quotation lines.
- **Predicted delta on Primary:** ledger 247 / `f2fd129466f76536d53779a131cda874`; functions `b526e294da3ac335350d2ad3758971e4`/323; the guard's prosrc `671c776f…` to `94fbaa14ed2af00aa74dd1d89225138e`, and its comment restated; combined `2e608d8e6162a3a466583fe2bb327566`/3115. Triggers, policies, constraints, grants, columns, views, indexes, status transitions and RLS are unchanged. No business row is written.
- **Stop at Gate 2.** No exact-byte owner authorization for the migration is recorded. Step 5 stops here. Secondary was not contacted.

### 2026-10-10 — Human Gate 2: owner authorization

- **Authority:** the owner's SPEC-258 Gate 2 authorization of 2026-10-10. It covers exactly the migration `supabase/migrations/20261010140000_a_quotation_line_stays_on_its_quotation_at_its_own_price.sql`, SHA-256 `663e759db30c6d594c08b9fae1fd6b8beb52fdcee42ff5ece0f74ab89270fd91`, MD5 `0e7fbc0eb122af8a81106824b9b0ae2b`, 5900 bytes, 94 lines, ASCII, LF-only, to Primary `vrvtsxexkiiiivlkdxzp` only, by the approved procedure. Nothing else on Primary, and nothing on Secondary `brplkqmbzffpxqgkkdzo`.

### 2026-10-10 — Step 6: Primary deployment

- **Local recheck, immediately before the write:**
  - HEAD `86fd9f00e01a70bec006709a434df0578602afcf` on the chain `cb9573b → 0263b41 → 4d14161 → 86fd9f0`, 0 behind `origin/main`;
  - since Draft `cb9573b`, this contract changed only its status lines and its Execution Log;
  - the migration hashes to its frozen identity (5900 bytes, 94 LF, 0 CR, ASCII), and test 150 to `9eea06b3…`; the register and disposition record hash as Step 3 left them;
  - the working tree touches only Write Scope paths.
- **Primary recheck, read-only:**
  - URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`;
  - ledger 246 `a6500a25aeb035493ac37f18cb46fb32`, latest `20261010120000`, the target absent by version and name, no row after it;
  - all ten structural surfaces equal the recorded evidence: functions `e3d51808…`/323, combined `f56111d6…`/3115;
  - the guard: prosrc `671c776f138de165d6f2e89a59183d63`, definition `f2b1fac44aa750a76cb79b92a1bdba04`, SECURITY DEFINER, owner `postgres`, ACL `{postgres=X/postgres}`, `search_path=""`, comment `QUO-2: …`;
  - the table: five enabled triggers, RLS on, `authenticated` INSERT, SELECT and UPDATE only;
  - 0 tenants, quotations, quotation lines and events.
- **Server-side proof:** the transmitted text hashed on Primary to MD5 `0e7fbc0eb122af8a81106824b9b0ae2b`, 5900 bytes, 94 LF, 0 CR.
- **Apply:** that same text, through the Primary connector's `apply_migration`, returned success. A fresh read showed one new row, temporary version `20261010144827`, with one stored statement, MD5 `0e7fbc0e…`, 5900 bytes, and 247 rows in all.
- **Reconciliation:** one guarded UPDATE renamed only that row to `20261010140000`. Every guard held, and it renamed 1 row:
  - 247 rows;
  - exactly one row after `20261010120000`;
  - the other 246 hashing to `a6500a25…`;
  - the statement MD5 equal to the file's;
  - no existing target.
- **Fresh post-write reads:**
  - ledger 247 `f2fd129466f76536d53779a131cda874`, latest `20261010140000`, exactly one row for the migration, the temporary version gone;
  - functions `b526e294da3ac335350d2ad3758971e4`/323, the other nine surfaces unchanged, combined `2e608d8e6162a3a466583fe2bb327566`/3115;
  - the guard: prosrc `94fbaa14ed2af00aa74dd1d89225138e`, definition `1478a3e9138cdccf0feb0e260353be0a` and comment MD5 `8935802527ad541b515227dfc999f766`, each equal to local; SECURITY DEFINER, owner `postgres`, ACL `{postgres=X/postgres}`, `search_path=""`;
  - the same five enabled triggers, RLS on, unchanged grants;
  - 0 tenants, quotations, quotation lines and events. No business-data write.
- **Secondary** `brplkqmbzffpxqgkkdzo` was not contacted.

### 2026-10-10 — Step 7: evidence and measured state

- **The evidence file, `reports/evidence/primary-ledger-evidence.json`,** was written from the fresh post-write readings only:
  - `read_at` `2026-10-10T14:50:44Z`;
  - `repository_head` `86fd9f00…`;
  - 247 migrations, `f2fd1294…`;
  - functions `b526e294…`/323, structural `2e608d8e…`/3115;
  - the ledger list appends `20261010140000_a_quotation_line_stays_on_its_quotation_at_its_own_price`.
- **Manifest:** `Live state` reads 247 migrations, the new ledger, function and structural hashes, and `Suite **150 files / 2778 assertions**`, with 464 HTTP assertions last passed 2026-10-10. Coverage reads 37 of 78, all thirty-seven at `ADVERSARIAL`. `supabase/tests` holds 150 files whose literal `plan(N)` values sum to 2778.
- **Register:** QUO-9 and QUO-10 read `DEPLOYED to Primary under separate exact-byte owner authorization`, with Cert `✅`.
- **Generated artifacts:** `MASTER_API_CONTRACT.md` regenerates unchanged (80 RPC endpoints, 8 views, 74 tables). `ai-map.json` is regenerated and stored LF.
- **Runtime Checkpoint** is `DONE`.
- **Checks:**
  - `check_primary_ledger.ps1`: RECOVER-1 `CLEAN`;
  - `check_database_parity_evidence.ps1`: `DATABASE PARITY: CLEAN` and `PRIMARY PARITY EVIDENCE: CLEAN`;
  - repository consistency: `CLEAN`;
  - `git diff --check`: exit 0.
- **CI-only guard self-tests, on this deployed state:** `test_future_date_guard`, `test_status_contradiction_guard`, `test_primary_ledger_guard` and `test_cold_start_state_guard` each pass, exit 0 (3.6, 3.1, 0.3 and 4.1 min). The CONTROL and restore cases that the pre-deploy drift failed at Step 4 now pass.

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
  - QUO-9 and QUO-10 were reproduced by an employee proven first to hold the capability, on quotations built through the RPCs, and the authority half by a second employee proven to carry the DENY. The race was reproduced in two live sessions, with the RPC refusing under the same timing.
  - Test 150 fails 19 assertions for their intended reasons with the pre-repair guard installed.
  - Each arm of the guard is pinned by an installed, killed mutant, and the lock also by a two-session kill.
- **WORTH IT.**
  - The quotation total is the figure a customer is offered and the one its sent and accepted events record. The table door could make it any number, sum two currencies into it, or empty an offer already sent and have it accepted at 0.
  - A user denied quotation authoring could still move that total.
- **SIMPLIFY IT WITHOUT WEAKENING.**
  - One existing guard's body, in QUO-2's and QUO-7's shapes, and its comment. Nothing else changes: no trigger, table, column, grant, policy, constraint, permission or function besides it.
  - Every legitimate draft edit, through either door, still works.
- **Owner direction (2026-10-10).** The owner named Batch 6 Slice 36 (`quotation_items`) and directed it through the existing lifecycle. `CR_LIFECYCLE.md` makes `Draft -> Approved` a human act, so this Draft stops at Gate 1. Approval, when given, still does not authorize any Primary write; Gate 2 is separate.
- **Deliberately not changed:**
  - `app.add_quotation_item`'s argument precision (Risks);
  - FIN-3's money-column rule and the denied employee's non-money edits;
  - `created_at`, which has no reader;
  - canon 24, 27, 28, 29 and 31;
  - the n8n workflow, PH8-10 and Phase 8;
  - the registered worktrees `wt251`, `wt255`, `owt/p2` and `C:\w234`.
