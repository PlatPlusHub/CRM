# Change Request — SPEC-215

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make every creation of a `public.suppliers` row, through any door, record exactly one `supplier_created` event attributed to the session that created it, by moving the event's single producer from inside `app.create_supplier` onto the table, while every other rule, guard, grant and path on `suppliers` stays exactly as it is today.

## Business Reason

Batch 6 Slice 15 selected `suppliers` by measurement (`scripts/batch6_select_target.ps1` at `4c47832`: Exposure **13**, first; `documents` second at 13, behind on coverage 100 vs 134). `authenticated` holds table-level INSERT on `suppliers` and PostgREST serves it beside `app.create_supplier`. Canon 27 catalogues `supplier_created` and canon 30 requires every meaningful business action to create an event, but only the RPC emitted it. One defect reproduced against the clean local stack, in one rolled-back transaction, and is recorded here as:

- **SUP-5 (Medium)** — a supplier created at the table door was silent. A `senior_employee` at `aal2` holding ASSIGN_SUPPLIER created one supplier through `app.create_supplier` (**1** `supplier_created` event, actor = the senior) and one by direct INSERT with `created_at` set to `2019-01-01` (**0** events, **0** security events; `created_at` stored as `2019-01-01`). `suppliers` has no creator column, so for that row nothing anywhere records who added a payee to the supplier master or when. Medium, not High, and the bound is measured: what happens to a supplier afterwards stays attributed (`app.record_supplier_payment` emits `supplier_payment_recorded`), and no function reads `supplier_created` today; what is lost is the attribution of the creation itself.

## Risks

- **Double recording is the main risk.** If the RPC kept its own `record_event` call beside the new trigger, every RPC creation would be recorded twice; the call is removed in the same migration and the new file asserts exactly one (3). Measured under the prototype: RPC path 1 event, table door 1 event, edit 0 further events, refused creation 0 events, session-less path 1 event with a null actor.
- **Session-less writers now produce events.** Migrations, seeds and 14 pgTAP fixtures insert suppliers as `postgres`; each now records one event with a null actor, which `app.record_event` requires outside a session. With the prototype installed the whole suite passed (121 files, 2025 assertions) on a clean reset and again after the six HTTP suites.
- **Primary deployment is irreversible** and is gated by an explicit owner authorization inside Step 6, not by this contract's approval alone.
- Not repairing leaves the supplier master open to unattributed, backdatable additions by any ASSIGN_SUPPLIER holder, while the same act through the RPC is recorded.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-215-supplier-creation-is-recorded.md`
- `supabase/migrations/20260924130000_supplier_creation_is_recorded.sql`
- `supabase/tests/121_supplier_creation_is_recorded_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607051100_master_data_write_paths.sql`
- `supabase/migrations/202607053000_event_write_path_integrity.sql`
- `supabase/migrations/202607059900_a_ceiling_with_no_currency_is_not_an_amount.sql`
- `supabase/migrations/20260920120000_membership_authority_and_audit.sql`
- `supabase/tests/12_catalog_code_enforcement_test.sql`
- `supabase/tests/26_duplicate_prevention_test.sql`
- `supabase/tests/35_subscription_write_gate_test.sql`
- `supabase/tests/86_supplier_credit_visibility_test.sql`
- `supabase/tests/90_supplier_credit_write_authority_test.sql`
- `supabase/tests/93_supplier_credit_threshold_test.sql`
- `supabase/tests/98_supplier_credit_parity_test.sql`
- `supabase/tests/100_notification_delivery_lifecycle_test.sql`
- `scripts/verify_database.sql`
- `scripts/verify_role_journeys.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`
- `reports/README.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/31_schema_draft.md`
- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `GOVERNANCE.md`

## Required Reading

- `reports/master/MASTER_SURFACE_DISPOSITION.md` — the `suppliers` row and the Coverage section
- `reports/master/MASTER_GAP_REGISTER.md` — SUP-1 to SUP-4c, USR-1 (the shape reused), ARCH-2 (whose `suppliers` instance this slice reproduced and does not absorb), and the `QUO-8` row the new row follows
- `supabase/migrations/20260920120000_membership_authority_and_audit.sql` — `app.emit_membership_change`, the single-producer shape copied
- `supabase/migrations/202607059900_a_ceiling_with_no_currency_is_not_an_amount.sql` — the current `app.create_supplier`
- `supabase/migrations/202607053000_event_write_path_integrity.sql` — `app.record_event`, which owns the actor and the time
- `ENGINEERING_METHOD.md §4` — the DATABASE protocol, and that Primary for this repository is only `vrvtsxexkiiiivlkdxzp`
- `reports/evidence/primary-ledger-evidence.json` — the current recorded Primary reading and its `read_query`

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
| `supplier_created` is produced by an AFTER INSERT trigger on `public.suppliers` instead of inside `app.create_supplier` | `app.create_supplier` | VERIFY | Its body differs from `202607059900`'s only by the removed `record_event` call; authority, checks and insert unchanged. The RPC path records exactly one event with the caller as actor and the RPC's payload keys and values (new file 2-3) |
| same | HTTP callers of `create_supplier`: `verify_role_journeys`, `verify_journey_branches`, `verify_lifecycle_branches` | VERIFY | Each exited 0 against the prototype-installed stack (120, 74 and 122 passed) |
| same | session-less writers — migrations, seeds and the 14 pgTAP files whose fixtures insert suppliers as `postgres` | VERIFY | Each now records one event with a null actor (16); `app.record_event` refuses a named actor outside a session. Whole suite passed with the prototype |
| same | readers of `supplier_created` in any function, view or policy | UNAFFECTED | Measured: none. Before this change the only function naming it was `app.create_supplier` |
| same | tests and suites that count events | VERIFY | Whole suite 121 files / 2025 assertions passed on a clean reset and after the six HTTP suites; every HTTP-suite event count is filtered to another event type |
| same | `suppliers_probe_credit_ceiling` (AFTER INSERT OR UPDATE) and `app.evaluate_supplier_credit_threshold` | UNAFFECTED | Independent trigger, not named; AFTER triggers fire by name, so `supplier_created` precedes any threshold event for the same row. `93_…` and `98_…` passed unchanged |
| same | UPDATE through the designed PATCH door | UNAFFECTED | The trigger fires on INSERT only; an edit records nothing further (7-8) |
| any | `suppliers_guard_credit_authority`, `suppliers_guard_write_capability`, `suppliers_enforce_archive_authority`, `suppliers_enforce_subscription_write_gate`, `suppliers_enforce_catalog_codes`, the `tenant_isolation` policy, every grant | UNAFFECTED | Not named by the migration; 9 and 11-15 pin the credit, tenant and archive boundaries this slice swept |
| a new trigger and SECURITY DEFINER trigger function | `10_grant_model_test.sql`'s PUBLIC-EXECUTE class assertion and the whole pgTAP suite | VERIFY | `revoke execute … from public` is part of Step 1; whole suite passed |
| same | `reports/master/MASTER_API_CONTRACT.md` (GENERATED, Check L3) | VERIFY | Regenerated from the prototype-installed stack: byte-identical to the committed file. In Write Scope because the Gate derives it for any migration contract |
| same | `scripts/verify_database.sql` | UNAFFECTED | Against the prototype: `ALL CHECKS PASSED (77 tables, … 71/621 catalog …)` |
| migration set 221 → 222, function surface +1, structural surface | `reports/evidence/primary-ledger-evidence.json`; `_ORVION_CANONICAL/manifest.md` `Live state:` | WRITE | Rewritten from a post-deployment Primary read (GUARD-1), never from a repository list |
| pgTAP suite 120 → 121 files and its declared assertion total | `_ORVION_CANONICAL/manifest.md` `Live state:` (Check 15) | WRITE | Remeasured after the new file lands, never incremented on paper |
| finding SUP-5 | `reports/master/MASTER_GAP_REGISTER.md` | WRITE | Check 22 rejects a disposition row citing an unregistered id |
| `suppliers` disposition and coverage 15 → 16 of 77 | `reports/master/MASTER_SURFACE_DISPOSITION.md`; the manifest's `Batch 6 surface coverage` line | WRITE | Check 22 recomputes the Coverage totals from the rows; Check 24 requires the cited file's `-- ATTACK-CLASSES:` line and a negative assertion |
| dated content added to both Master documents | Check 21 freshness headers | WRITE | Each document's `Last updated:` moves in the same step that adds its dated content |
| any | `scripts/batch6_select_target.ps1` | UNAFFECTED | Stores nothing and reads the disposition file; the row change removes this surface from its NOT-RECORDED candidates |
| any | `reports/README.md`; the manifest's `Narrative:` field | UNAFFECTED | No session report is written; this contract is the immutable evidence artifact, as `SPEC-214` did |

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

Existing Mechanism: The shape is reused verbatim from `app.emit_membership_change` (USR-1, `20260920120000`): one AFTER trigger as the single producer, the RPC's own emission removed, the session-less path recorded with a null actor. But no existing control on `suppliers` records creation: its seven triggers guard authority, catalog codes, subscription state, archive authority and the credit ceiling, and the only emitter was inside the RPC. REVOKE of the INSERT grant was rejected: `app.create_supplier` is SECURITY INVOKER and depends on it (the `trusted_devices` lesson), and `35_…` and `98_…` pin the INSERT door's own behaviour, so closing the door would move their refusals to a different mechanism and flip the RPC's security mode. A server-stamped creator column was rejected: canon 31 names no such column, it would still leave the canon-27 event missing, and it is a schema change where one trigger suffices. A shared direct-DML event-parity mechanism was not considered for promotion: the same question stands unclassified on `quotations` and `offline_conversions`, and a shared mechanism would change surfaces no slice has classified.

Added Property: every `suppliers` row, created through any door, has exactly one `supplier_created` event attributed to the creating session (or to no one for a session-less system write) and stamped with the server's time.

Causal Negative: reproduced against unmodified `4c47832` on the local stack, in one rolled-back transaction: a `senior_employee` at `aal2` created `Rpc Air` through `app.create_supplier` (1 `supplier_created`, actor = the senior) and `Shell Air` by direct INSERT with `created_at = '2019-01-01'` (0 events, 0 security events; `created_at` stored as 2019-01-01). `suppliers` has no creator column.

Positive Test Design: the RPC creates a supplier; the table door creates a supplier; the designed edit door edits an ordinary field; an ARCHIVE_RECORD holder archives a supplier; the session-less path creates one.

Negative Test Design: the observability claims are exact-value assertions on one summary string per supplier (event count / actor / payload), so zero, two, a wrong actor or a wrong payload all fail: RPC path `1/<senior>/{name, supplier_type_code}`; table door the same for its row; after an edit still exactly 1; a creation refused by the credit guard (`42501`, `permission denied: MANAGE_SUPPLIER_CREDIT`) leaves 0; the session-less path `1/-/…`; the ledger's event time is the server's while the row still says 2019. The swept boundaries this repair does not own are asserted with their exact refusals: RLS refuses moving a supplier into, or planting one in, another tenant (`42501`, `new row violates row-level security policy for table "suppliers"`); archiving costs ARCHIVE_RECORD (`42501`, `permission denied: ARCHIVE_RECORD`) and an authorized archive's attribution is the server's. Every signed-in actor is at `aal2`; the `senior_employee` holds ASSIGN_SUPPLIER and neither ARCHIVE_RECORD nor MANAGE_SUPPLIER_CREDIT, asserted first.

Non-Empty Population Obligation: every observability assertion names one supplier by name and requires an exact count of 1 (or 0 for the refused and mutated cases) with a named actor, so none can pass by selecting nothing; the closing completeness assertion (every supplier in the tenant has exactly one `supplier_created`) is paired with the five positive creations in the same tenant.

Mutation Obligation: each load-bearing predicate independently killed, applied to Step 1's migration text on the clean-reset stack and restored by re-applying that text: (M1) protection removed — the emitter's body a no-op returning null, trigger kept: 3, 5, 6, 8, 16, 20 and 21 red; (M2) double producer — `app.create_supplier` keeps its own `record_event` call: 3 and 21 red; (M3) widened — the trigger fires AFTER INSERT OR UPDATE: 8, 17 and 21 red. The unmutated text turns none red. Plus the in-file control: dropping the trigger inside a savepoint makes a door creation silent (19), and the same creation is recorded again after the rollback (20).

Post-Implementation Proof Obligation: `npx supabase test db` reports 0 failures and the assertions executed equal the sum of the literal `plan(N)` declarations across `supabase/tests`; the new file passes 21 of 21.

## Implementation Steps

1. **Check:** a file matching `supabase/migrations/20260924130000_*.sql` exists. If present, record Already Applied. Otherwise create `supabase/migrations/20260924130000_supplier_creation_is_recorded.sql` containing a leading comment block that names `SPEC-215 / SUP-5` and states the rule, followed by exactly these four statements and nothing else: (a) `create or replace function app.emit_supplier_created() returns trigger language plpgsql security definer set search_path to ''` whose body calls `app.record_event(new.tenant_id, 'supplier_created', 'supplier', new.id, app.current_user_id(), null, null, null, jsonb_build_object('supplier_type_code', new.supplier_type_code, 'name', new.name), 'info')` and returns null; (b) `revoke execute on function app.emit_supplier_created() from public;` (c) `create trigger suppliers_emit_created after insert on public.suppliers for each row execute function app.emit_supplier_created();` (d) `create or replace function app.create_supplier(p_name text, p_supplier_type_code text, p_phone text default null, p_email text default null, p_payment_term_code text default null, p_credit_limit_amount numeric default null, p_credit_limit_currency_code text default null) returns uuid language plpgsql set search_path to ''` whose body is the body `202607059900_a_ceiling_with_no_currency_is_not_an_amount.sql` gives it, with its `perform app.record_event(...)` statement replaced by one comment line stating that `supplier_created` is emitted by `suppliers_emit_created`, and no other change. The migration must not change any grant, policy, index, constraint, other trigger or other function.

2. **Check:** `supabase/tests/121_supplier_creation_is_recorded_test.sql` exists. If present, record Already Applied. Otherwise create it in the `begin; select plan(21); … select * from finish(); rollback;` shape, carrying the line `-- ATTACK-CLASSES: OBSERVABILITY DOOR TENANT STATE PRIVILEGE CONCURRENCY=N/A REPLAY=N/A` with the reason for each `N/A` and for the undeclared AUTH, INPUT and BUSINESS stated in the header, and asserting in this order: 1 the `senior_employee` actor holds ASSIGN_SUPPLIER and neither ARCHIVE_RECORD nor MANAGE_SUPPLIER_CREDIT; 2 RPC create succeeds; 3 its row has exactly one `supplier_created` with the senior as actor and the payload `{"name", "supplier_type_code"}`; 4 a direct INSERT with `created_at` 2019-01-01 succeeds; 5 its row has exactly one `supplier_created` with the senior as actor; 6 that event's time is the server's while the row's `created_at` is before 2020; 7 a direct phone edit succeeds; 8 the row still has exactly one event; 9 a direct INSERT carrying a credit ceiling is refused `42501 permission denied: MANAGE_SUPPLIER_CREDIT`; 10 no `supplier_created` names that supplier; 11 moving a supplier to another tenant is refused `42501` with the RLS message; 12 planting one in another tenant is refused the same; 13 archiving by the senior is refused `42501 permission denied: ARCHIVE_RECORD`; 14 an `owner` archives it with a forged archiver and time; 15 the stored archiver is the owner and the time is the server's; 16 the fixture supplier written as `postgres` has exactly one event with a null actor; 17 `app.emit_supplier_created` is SECURITY DEFINER, executable by neither PUBLIC nor `authenticated`, and exactly one trigger fires it AFTER INSERT only; 18 `authenticated` holds no DELETE on `public.suppliers`; 19 with the trigger dropped inside a savepoint a door creation has no event; 20 after the rollback the same creation has exactly one; 21 every supplier in the tenant has exactly one `supplier_created`. Signed-in actors are a `senior_employee` and an `owner`, both at `aal2`.

3. **Check:** `reports/master/MASTER_GAP_REGISTER.md` contains a row whose first cell is `SUP-5`. If present, record Already Applied. Otherwise insert, immediately after the `QUO-8` row and separated by one blank line as the neighbouring rows are, one row in the table's existing thirteen-column format: `SUP-5`, a bold title stating that a supplier created at the table door was silent while the RPC recorded it, category `audit completeness · observability`, severity **Medium**, `R`, batch `6`, `A`, `✅`, a status cell beginning `**✅ FIXED 2026-09-24 (SPEC-215, `20260924130000`).**` followed by the measured reproduction from this contract's Business Reason, the severity bound, and the repair in one sentence, an EMPTY Owner Decision cell, source `SPEC-215`, added `09-24`, updated `09-24`. Also prepend a new `Last updated: 2026-09-24 (…)` entry describing SUP-5 and demote the current one to `Previously:` in the file's existing voice. Change no other row.

4. **Check:** `reports/master/MASTER_SURFACE_DISPOSITION.md`'s `suppliers` row reads `NOT-RECORDED`. If it does not, record Already Applied. Otherwise set that row to disposition `AUDITED-OPEN`, assurance `ADVERSARIAL`, session `SPEC-215-supplier-creation-is-recorded`, findings `SUP-5, ARCH-2`, and a Next cell stating: that SUP-5 was closed by `121_...`; that ARCH-2's `suppliers` instance (a row born archived by a user without ARCHIVE_RECORD) was reproduced in this slice and stays with ARCH-2's row, which is why the surface is `AUDITED-OPEN`; that the following were swept and classified as non-defects, not registered — tenant relocation and planting (RLS), archive authority and attribution on UPDATE (`app.enforce_archive_authority`), both doors agreeing at `aal1`, a blank name and a case-variant duplicate at the table door (a name is freely editable there and the RPC itself admits a near-variant, so neither changes what an ASSIGN_SUPPLIER holder can do), and `is_internal` / `internal_branch_id` / `internal_department_id`, which nothing reads; and that whether an archived supplier may still be assigned new work is a rule no code or canon states, belonging to `booking_items`' supplier assignment rather than to this table. Update the Coverage summary to `16 of 77 recorded · 6 `AUDITED` · 8 `AUDITED-OPEN` · 2 `PARTIAL` · 0 `EXEMPT` · 61 `NOT-RECORDED`` and its sentence to `All 16 recorded surfaces stand at `ADVERSARIAL``. In the same step, prepend a new `Last updated: 2026-09-24 (…)` entry for slice 15 and demote the current one to `Previously:`. Change no other row.

5. **Check:** the Execution Log contains an entry headed `Pre-deploy readiness gate`. If present, record Already Applied. Otherwise perform the gate and record every item's measured result in the Execution Log; the first item that does not hold is a STOP, and nothing is deployed while it stands:
   - a clean `npx supabase db reset` completed;
   - pgTAP **Pass A** (`npx supabase test db`) ran with 0 failures, and the assertions executed equal the `plan(N)` sum;
   - the six Additional Verification suites ran in the listed order, each exiting 0;
   - pgTAP **Pass B** ran after those suites with 0 failures;
   - `scripts/verify_database.sql` completed with `ALL CHECKS PASSED`;
   - the three mutants of the Mutation Obligation were each applied to the text of Step 1's migration on the clean-reset stack and restored by re-applying that text, and each turned red the assertions this contract names for it; the unmutated text turned none red;
   - `pwsh -NoProfile -File scripts/generate-api-contract.ps1` regenerates `reports/master/MASTER_API_CONTRACT.md` byte-identically;
   - `git status --porcelain` shows no path outside this contract's Write Scope;
   - `supabase/migrations/` contains exactly one migration absent from the recorded Primary ledger, and it is the file Step 1 created;
   - `pwsh -NoProfile -File scripts/check_repository_consistency.ps1` is run and its result recorded. Exactly three failure classes are admissible, all the same bounded undeployed state: `MIGRATION STATE DRIFT`; `SUITE FIGURE DRIFT`; and RECOVER-1 / Check 19 only when its `only in repository` set is exactly `20260924130000_supplier_creation_is_recorded` and its `only on Primary` set is empty. Any other failure is a STOP.

6. **Check:** `reports/evidence/primary-ledger-evidence.json`'s `ledger` array contains an entry beginning `20260924130000`. If present, record Already Applied. Otherwise, **first confirm that the owner has explicitly authorized Primary deployment of SPEC-215 after Step 5 was recorded, and record that authorization in the Execution Log; without it, set `Blocker:` to the owner gate and STOP here.** Then, in this order and stopping at the first step that does not hold: (a) confirm the target is project ref `vrvtsxexkiiiivlkdxzp` by reading it live through the `supabase-primary` connector, and that it is not Secondary `brplkqmbzffpxqgkkdzo`; (b) read Primary's migration ledger with the exact query recorded in the evidence file's `read_query`; (c) prove `20260924130000` is absent and the ledger equals the recorded evidence (same `migration_count` and `ledger_fingerprint`); (d) apply ONLY Step 1's migration through the connector's migration-apply call; (e) if the connector assigns its own version, normalise it in Primary's ledger to `20260924130000`, as already done for `20260924120000`; (f) re-read Primary's full ledger with the same query; (g) rewrite the evidence file from that post-deployment reading, including the function-surface and structural-surface hashes read FROM Primary; (h) prove repository, local and Primary hold the same migration identities; (i) run `pwsh -NoProfile -File scripts/check_database_parity_evidence.ps1` and record its result. If any post-deployment operation fails, STOP and report Primary's exact state as read; do not re-apply and do not author a corrective migration.

7. **Check:** `_ORVION_CANONICAL/manifest.md`'s `Batch 6 surface coverage` line reads `16 of 77`. If it does, record Already Applied. Otherwise, after Step 6, update by measurement only: set that line to `16 of 77` (sixteen at `ADVERSARIAL`); remeasure and rewrite every mutable figure in `Live state:` — migration count and latest identity, ledger fingerprint, function-surface hash and function count, structural-surface hash and object count, test-file count and declared assertion total, and the HTTP assertion total — from measurement, never by incrementing; set `Last Completed` to SPEC-215 REPLACING the SPEC-214 entry; and set `Next capability` to Batch 6 Slice 16 ranked by `scripts/batch6_select_target.ps1`, keeping the standing facts that follow it. Do not modify `Narrative:`. The `Live state:` sentence may claim Primary parity only if Step 6 read Primary and proved it.

8. **Check:** `ai-map.json`'s `live_state` copies of `Last Completed`, `Active Change Request` and `Next capability` equal the manifest's by value. If they agree, record Already Applied. Otherwise regenerate with `pwsh -NoProfile -File scripts/generate-ai-map.ps1` and normalise the file to LF before committing. Repeat after every commit in this lifecycle that changes the manifest, including Approve and Complete.

9. **Check:** the Execution Log contains an entry headed `Post-deploy verification`. If present, record Already Applied. Otherwise run `pwsh -NoProfile -File scripts/check_database_parity_evidence.ps1`, `pwsh -NoProfile -File scripts/check_primary_ledger.ps1` and `pwsh -NoProfile -File scripts/check_repository_consistency.ps1`, and record each exit code; all three must exit 0.

## Acceptance Criteria

- [ ] `supabase/migrations/20260924130000_supplier_creation_is_recorded.sql` exists and contains exactly the function, the revoke, the trigger and the `app.create_supplier` replacement Step 1 names, and no grant, policy, index, constraint, other-trigger or other-function change.
- [ ] `public.suppliers` carries exactly one trigger executing `app.emit_supplier_created`, firing `AFTER INSERT` only; the function is SECURITY DEFINER and grants no `EXECUTE` to `PUBLIC`.
- [ ] `app.create_supplier` differs from its `202607059900` definition only by the removed `record_event` statement and the comment that replaces it, and every RLS policy, grant and other trigger on `public.suppliers` is identical to its definition at the start of this Change Request.
- [ ] `supabase/tests/121_supplier_creation_is_recorded_test.sql` exists, declares `-- ATTACK-CLASSES:` from the closed vocabulary, plans 21, contains `throws_ok`, and contains the in-file mutation control that drops the trigger inside a savepoint.
- [ ] That file's observability assertions compare exact event count, actor and payload per named supplier, and its signed-in actors are a `senior_employee` holding ASSIGN_SUPPLIER without ARCHIVE_RECORD or MANAGE_SUPPLIER_CREDIT and an `owner`, both at `aal2`.
- [ ] `npx supabase test db` reports 0 failures and the assertions executed equal the sum of the literal `plan(N)` declarations across `supabase/tests`.
- [ ] The Execution Log records all three mutants of the Mutation Obligation, each turning red the assertions this contract names for it, and the unmutated migration turning none red.
- [ ] `reports/master/MASTER_API_CONTRACT.md` is byte-identical to its state at the start of this Change Request.
- [ ] `reports/master/MASTER_GAP_REGISTER.md` carries a `SUP-5` row, FIXED by SPEC-215 with an empty Owner Decision cell, and its `Last updated:` entry is dated 2026-09-24.
- [ ] `reports/master/MASTER_SURFACE_DISPOSITION.md` records `suppliers` as `AUDITED-OPEN` / `ADVERSARIAL` citing `SPEC-215-supplier-creation-is-recorded` and `SUP-5, ARCH-2`, its Next cell names ARCH-2's instance, the swept non-defects and the archived-supplier assignment question, and its Coverage summary reads 16 of 77 with eight `AUDITED-OPEN`.
- [ ] `reports/evidence/primary-ledger-evidence.json` names `project_ref` `vrvtsxexkiiiivlkdxzp`, contains `20260924130000` in its `ledger` array, and its `migration_count` and `ledger_fingerprint` are consistent with that array.
- [ ] The repository migration filename set, the local migration set and the Primary ledger recorded in that evidence file contain the same migration identities.
- [ ] `_ORVION_CANONICAL/manifest.md` records Batch 6 coverage as 16 of 77, names SPEC-215 as `Last Completed` in place of SPEC-214, names Batch 6 Slice 16 as `Next capability`, and writes every mutable `Live state:` figure from a post-deployment measurement.
- [ ] `ai-map.json`'s live_state copies of `Last Completed`, `Active Change Request` and `Next capability` match the manifest by value, and the file is stored with LF line endings.
- [ ] The Execution Log records the owner's explicit Primary deployment authorization before the deployment, and the pre-deploy readiness gate's measured result for every item.
- [ ] No file outside this contract's Write Scope was created, modified or deleted.

## Execution Log

## Verification Notes

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as
      Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's
      Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

Evidence gathered before this contract was frozen, all local, synthetic and rolled back unless stated. The reproduction ran at `4c47832` against the migration set ending `20260924120000`. The candidate was then installed on the local stack for the suite runs, and the stack was reset to the repository afterwards.

- **Prototypes, LF line endings** (provenance only; they live outside the repository, so no step depends on reproducing their bytes): migration SHA-256 `257e63d60e98947c2d488319f29ec94b614f34cdd22f699507345687c25d9b44`; test SHA-256 `8880a97c94d7662e2521230d46eecb6cb71b02df802acdf46e32607dfd8be09e`. The new file passed 21/21 on the prototype stack.
- **Differential and whole suite:** with the candidate installed on a clean reset the whole suite passed (121 files, 2025 assertions); the six HTTP suites then exited 0 (33, 120, 40, 74, 122 and 60 passed, 449 in total); pgTAP Pass B after them passed again (121 files, 2025). `verify_database.sql`: `ALL CHECKS PASSED`. `MASTER_API_CONTRACT.md` regenerated with no diff. Differential probe on the candidate: RPC 1 event with the same actor and payload as before; door 1 event with the true server time; PATCH 0 further; a refused creation 0; session-less 1 with a null actor.
- **Mutants**, measured against the final text: M0 none red; M1 (no-op emitter) red 3, 5, 6, 8, 16, 20, 21; M2 (RPC keeps its emission) red 3, 21; M3 (AFTER INSERT OR UPDATE) red 8, 17, 21. Restored text 21/21 after each. **An equivalent mutant is recorded rather than counted:** passing `null` instead of `app.current_user_id()` as the actor turned nothing red, because `app.record_event` ignores the argument inside a session (taking the actor from the session) and refuses a non-null one outside a session. The actor is not this trigger's to decide, which is the stronger property; the migration's header says so.
- **A first framing was corrected by the evidence.** Dropping the trigger out-of-file as M1 collided with the file's own in-file drop and aborted the rest of the run, so M1 is the no-op body, which is the realistic weakening and leaves the in-file control meaningful.

**Swept and classified in this slice, not registered**, each with the measurement that classified it:
- **Tenant:** moving a supplier into another tenant, or planting one there, is refused `42501` by the `tenant_isolation` policy's WITH CHECK — the intended control.
- **Archive on UPDATE:** a `senior_employee` without ARCHIVE_RECORD is refused `42501 permission denied: ARCHIVE_RECORD` by `app.enforce_archive_authority`; an `owner`'s forged `archived_at` 2001 and `archived_by` <senior> are overwritten with the server's values (INVOICE-6).
- **Archive on INSERT:** a supplier born archived by the senior succeeds — ARCH-2's `suppliers` instance, reproduced, owned by ARCH-2's row and not absorbed.
- **AUTH:** at `aal1` both the RPC and the PATCH door succeed for ASSIGN_SUPPLIER — the doors agree, so there is no door disparity.
- **INPUT / BUSINESS:** the RPC refuses a blank name and a case-variant duplicate (`NILE AIR` beside `Nile Air`); the table door stores both (`suppliers_unique_name_idx` is case-sensitive). Not defects: the PATCH door is the designed edit door and a name is freely editable there (the role journeys pin that it stores input verbatim, e.g. an un-normalised phone), the RPC itself admits `Nile  Air`, and canon 31 requires only that `name` exist.
- **`is_internal`, `internal_branch_id`, `internal_department_id`:** incoherent combinations are accepted, and no function, view, policy or application path reads any of the three.
- **Archived supplier still assignable:** `app.create_booking_item` checks only the supplier's tenant. No code or canon states that an archived supplier may not receive new work, so there is no rule for a door to skip; the question belongs to `booking_items`' supplier assignment.

**Candidate selection**, recorded so it is not re-litigated: **A** (this contract, USR-1's single-producer emitter) was prototyped and passed everything above; **B** (REVOKE INSERT) and **C** (a server-stamped creator column) were rejected without being built, for the reasons in Existing Mechanism.
