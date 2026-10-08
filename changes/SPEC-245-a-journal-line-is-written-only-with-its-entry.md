# Change Request — SPEC-245

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Foundation Completion Programme Batch 6 Slice 32: give `public.journal_entry_lines` a truthful disposition. Close two defects:
- **JE-3:** a posted journal line could be rewritten, re-accounted, moved or appended to at the table door, at aal1 as well as aal2, while its `journal_entry_created` event kept the original total.
- **JE-4:** the balance check judged only the entry a line moved to, and two transactions could empty one entry from two sides.

After this change a journal line is written only by `app.create_journal_entry`, with the entry it posts, and never changes afterwards. Record JE-5, the same question on the `journal_entries` header, for that surface's own slice. Leave JE-2 open. Record the surface `AUDITED-OPEN`, and set the next capability to the Slice-33 target the selector then measures.

This contract does not touch n8n, any Phase-8 work, BOOK-11, BOOK-12, PAY-5, CONV-9, CONV-10, JE-2 or DC-11, and builds no reversal workflow.

## Business Reason

### Selection
`scripts/batch6_select_target.ps1` at `3c34870` ranks `journal_entry_lines` first: `NOT-RECORDED`, Exposure 8, coverage 26, 5 test files, a money column, 2 direct writes and 1 RPC. The runner-up is `tenant_license_activations` at 8/30.

### Authority
- **Canon 07:** "Any correction after approval must be handled through a new event, adjustment, reversal, or authorized finance action."
- **The register's `journal_entries` closure** applies that to the ledger: a POSTED double-entry record is corrected by a compensating reversal, never by mutation, and the header's void columns "must never be given a writer".
- **No draft state.** A journal entry has none: `app.create_journal_entry` writes the entry and all its lines in one call and records `journal_entry_created` with `total_amount` and `line_count`.
- **One writer, no other reader.** The RPC is the only function that writes a line. No function updates one, and no view or other function reads lines.
- **The door.** The RPC was SECURITY INVOKER, which is the only reason `authenticated` held INSERT and UPDATE on the lines. The RLS policies charge `app.has_permission('CREATE_JOURNAL_ENTRY')`, held by `ceo`, `finance_manager` and `owner`; the RPC charges `app.authorize`, which also requires MFA for those roles.

### JE-3 (High, latent)
Measured on the local stack at `3c34870`, rolled back, as a `finance_manager` at aal2:
- **Rewrite:** a posted 1000/1000 EGP entry became 7000/7000 USD on other accounts, backdated to 2001, while its event still said 1000.
- **Retired account:** a posted line moved onto account 1100 after it was retired, although the RPC refuses that account. JE-1's guard is attached to INSERT only.
- **Re-parent:** both lines of one entry moved into another.
- **Append:** a balanced pair of lines was appended to a posted entry.
- **Step-up:** at aal1 the RPC refused for want of MFA, while the same actor's direct rewrite landed.

Over PostgREST, each attack was a single request:
- a bulk POST appended a pair (201);
- an upsert rewrote both lines (200);
- a PATCH moved a line to another account (204);
- the same PATCH landed at aal1 (204).

A posted 2500/2500 entry ended at 14000/14000 across four lines in EGP and USD, with its one event still saying 2500. Exposure: Primary holds 0 journal lines.

### JE-4 (Medium, latent)
`app.enforce_journal_entry_balanced` took the affected entry as `coalesce(NEW, OLD)`. A line UPDATE that changes `journal_entry_id` therefore judged only the destination.
- **Re-parent:** moving both lines of an entry elsewhere committed, leaving it with zero lines, both for the finance manager and for the platform, which FIN-8 deliberately does not exempt.
- **Write skew:** with both parents judged, two platform sessions each moved half of one entry's four lines elsewhere. Each check saw the other's lines still present, there was no blocking edge, and both committed with the entry empty.

### The repair
One authority, the RPC, writes lines:
- **The RPC** now runs SECURITY DEFINER, as `app.merge_customer_identity` does. It keeps its `app.authorize` (permission and MFA), its tenant from the session and its empty `search_path`; its body is unchanged.
- **The door:** `authenticated` loses INSERT and UPDATE on `journal_entry_lines`. SELECT stays, and no DELETE grant ever existed.
- **The balance check** now judges every entry a line belongs to before and after, in id order, and locks each (`for no key update`) before counting. The second of two transactions then waits, counts the first one's committed change and is refused.

Nothing else changes. FIN-8's three rules, the per-row CHECKs, JE-1's INSERT guard (which still binds the platform) and the subscription gate stay as they are.

### Rejected
- Revoking UPDATE alone: one PostgREST bulk POST still appends to a posted entry.
- A "created in this transaction" guard: the header's xmin moves on any header UPDATE.
- Column grants: no field of a posted line is legitimately editable, and no writer edits one.
- A second `journal_entry_created` producer: FIN-9 already rejected it.
- A reversal workflow: canon defines none, and its absence does not license mutation.

### Held, recorded so a later slice does not rediscover it
- **FIN-8, MONEY-1:** the set rules and the NaN rule are unchanged.
- **Tenant isolation:** RLS plus composite keys to the entry and the account.
- **DELETE:** no grant.
- **Read scope:** tenant-wide, as for `chart_of_accounts`. Canon names no finer journal read, and ADR-0021 makes a finer finance read an RLS decision.
- **FIN-9:** re-measured, its residue is the platform writer alone (`postgres`, and `service_role` through Primary's default privileges).
- **JE-2:** stays OPEN by decision. A 100 USD debit still balances a 100 EGP credit through the RPC. One currency per entry, or translation to a base currency, is the accounting-model choice DC-11 owns. Test 145 pins it as open.

### JE-5 (Medium), recorded and not repaired here
`authenticated` still holds INSERT and UPDATE on `journal_entries`. An aal1 finance manager backdated a posted entry to 2001, re-described it, and set `is_voided`, `voided_at` and `void_reason` with `voided_by` empty. It touches no line: a header INSERT cannot commit without lines (FIN-8), and no signed-in user now writes a line. It belongs to `journal_entries`' own Batch-6 slice.

## Risks

- **A legitimate writer losing its door.** The only line writer is the RPC, which now needs no grant. No script or application writes lines directly.
  - Tests 70 and 89 used a signed-in direct line write only to prove FIN-8 and JE-1 on the direct path. They now ask the platform, which is the only remaining direct writer, and their purpose is unchanged.
  - Test 89's CLASS inventory loses the `create_journal_entry -> journal_entry_lines` pair, which no longer has a table door.
  - pgTAP 145 files / 2657 assertions and all six HTTP suites (458) pass on the prototype.
- **The RPC as definer.** It already pins `search_path ''`, takes no caller tenant (Test 102's SECDEF-1 class) and calls `app.authorize` before any write. Its derivations of `created_by`, the tenant and the active account are unchanged, and the `public` HTTP wrapper stays invoker (Test 53).
- **The lock.** It is taken only in the deferred commit-time check, on the entries being judged. An RPC posting locks only its own new entry.
- **Primary deployment** revokes two table privileges, changes one function's security mode and replaces one trigger function. Primary holds 0 journal entries and lines. It requires separate exact-byte owner authorization (Gate 2); approving this contract does not authorize it.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-245-a-journal-line-is-written-only-with-its-entry.md`
- `supabase/migrations/20261008120000_a_journal_line_is_written_only_with_its_entry.sql`
- `supabase/tests/145_a_journal_line_is_written_only_with_its_entry_test.sql`
- `supabase/tests/70_journal_entry_balance_test.sql`
- `supabase/tests/89_finance_periphery_parent_state_test.sql`
- `scripts/verify_journey_branches.ps1`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607047800_journal_entries.sql`
- `supabase/migrations/202607057300_a_ledger_entry_that_does_not_balance_is_not_a_ledger_entry.sql`
- `supabase/migrations/202607059500_money_allocated_to_an_invoice_that_was_never_issued.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/53_api_surface_test.sql`
- `supabase/tests/72_invoice_allocation_ceiling_test.sql`
- `supabase/tests/73_quotation_total_derivation_test.sql`
- `supabase/tests/83_actor_attribution_test.sql`
- `supabase/tests/102_financial_account_identity_and_definer_surface_test.sql`
- `supabase/tests/106_otp_challenge_subject_authority_test.sql`
- `reports/architecture-decision-records.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/07_finance_model.md`
- `_ORVION_CANONICAL/31_schema_draft.md`
- `scripts/verify_database.sql`
- `scripts/verify_customer_concurrency.py`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/07_finance_model.md` (corrections after approval); `_ORVION_CANONICAL/31_schema_draft.md` (`journal_entries`, `journal_entry_lines`); `_ORVION_CANONICAL/28_permissions_matrix.md` (CREATE_JOURNAL_ENTRY)
- `reports/master/MASTER_GAP_REGISTER.md` (FIN-8, FIN-9, JE-1, JE-2, DC-11, STEPUP-1, and the `journal_entries` CLOSED BY DESIGN block)
- `reports/master/MASTER_EXECUTION_PLAN.md` Batch 6 method and EC-1…EC-11; `reports/master/MASTER_SURFACE_DISPOSITION.md`
- Current local `app.create_journal_entry`, `app.enforce_journal_entry_balanced`, `app.guard_parent_state_allows_write`, `app.authorize`
- Tests 70, 89, 102

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

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| `authenticated` loses INSERT and UPDATE on `journal_entry_lines` | Tests 70 (FIN-8 direct path), 89 (JE-1 direct path, the CLASS inventory), 10, 106; PostgREST's table door; `verify_journey_branches.ps1` | WRITE | The prototype was applied as a real migration on a clean reset in scratch worktree `C:\w32` at `3c34870`: SHA-256 `74e957d1d1ce2372e1873c2e0413fbe0670161f7d958d76ff263b49f2aa502b0`. Test 70 asks the platform for its direct-path assertions 10–14 (SHA-256 `d2416a2851d6162a1caebacb14832e7f83431334c36d92123a6629865b5c36e0`, 19/19). Test 89 asks the platform for JE-1's 11 and 14, and its CLASS inventory drops the `create_journal_entry -> journal_entry_lines` pair (SHA-256 `982b0ee60942b67d49d44b4467632990dfd9cbcf8c3125d6ecbd0e825bd36659`, 21/21). Test 106 counts policies, not grants, and passes unchanged. `verify_journey_branches.ps1` gains five checks (SHA-256 `c2c2334074952c9f1811070cabdbbbfadd795155d8dd72e07aa5dd04ae6c3509`). With the line grants restored they FAIL (bulk POST 201; upsert 200; PATCH 204; PATCH at aal1 204; the entry left 14000/14000 on four EGP and USD lines), and on the repair they pass (79/0). |
| `app.create_journal_entry` becomes SECURITY DEFINER | Tests 53, 102; `verify_journey_branches.ps1`'s ledger block; `MASTER_API_CONTRACT.md` | VERIFY | Tests 53 (the `public` wrapper stays invoker) and 102 (definer reachable by `authenticated` pins `search_path` and takes no caller tenant) pass unchanged. The RPC still posts, still refuses an employee, an unbalanced entry and aal1. |
| The balance check judges both parents under a lock | Tests 70, 72, 73 (its trigger is in their constraint-trigger sets) | VERIFY | All pass unchanged. Two sessions, with an observed `pg_blocking_pids` edge: the second transaction is refused and the entry keeps its lines. Without the lock, both commit and the entry is empty. |
| The table's generated API row | `MASTER_API_CONTRACT.md` | WRITE | The generator reports 80 RPC endpoints (80 with HTTP evidence), 8 views and 74 tables. Exactly one line moves, `journal_entry_lines` `SIU-` → `S---` (prototype SHA-256 `482548e32c7328b1bd435a03efcc850176671a607a1650c8358016c2226c54ee`). `ai-map.json` differs only in `generated_at`. |
| Suite, HTTP and smoke | full pgTAP; the six HTTP suites; `scripts/verify_database.sql` | VERIFY | On the prototype, on a clean reset, in `-Finish`'s order: pgTAP Pass A 145 files / 2657 assertions PASS (2638 + 19); HTTP 35 + 40 + 79 + 122 + 122 + 60 = 458 passed, 0 failed; Pass B 145 / 2657 PASS; smoke `ALL CHECKS PASSED (78 tables, … 71/622 catalog, …)`. |
| Measured state that moves | manifest (`Live state`, suite and HTTP figures, coverage, Last Completed, Current Module, Next capability); `primary-ledger-evidence.json`; `ai-map.json` | WRITE | 241 → 242 migrations, latest `20261008120000`; 144 → 145 files, 2638 → 2657 assertions; HTTP 453 → 458; coverage 32 → 33 of 78. Tables (78), catalog (71/622) and client RPCs (80) do not move. Primary values are written only from fresh post-deploy readings. |
| JE-3, JE-4, JE-5 recorded; JE-1, FIN-9 and STEPUP-1 annotated; the surface `AUDITED-OPEN` | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24 | WRITE | Prototype SHA-256 values: register `fd07e8104e5fd80bf43cd112b37a937ab052ddc1acf51faeaefb1afe3debd502`, disposition `b00dce7bd66a750ee20d0552d697b4fce64700f9b646d870f6cc858417b0fc9e`. |
| CI-only guard self-tests | `scripts/test_*_guard.ps1` (four) | VERIFY | On the prototype, future-date (18/0) and status-contradiction (33/0) pass. Primary-ledger (2 failed) and cold-start (9 failed) fail only their clean-repository CONTROL cases, as at SPEC-244's same boundary. Repository consistency reports the six expected pre-deploy issues: three migration-state drifts, two suite-figure drifts and RECOVER-1. It also reports one prototype-only issue: the disposition's session pointer to this contract, which the prototype tree lacks. The open-decision line keeps MAIL-1, RET-1 and PH8-10. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused tests, pgTAP A/B, the six HTTP suites, smoke and mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| JE-3, JE-4, JE-5 and the disposition describe the local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |
| The four CI-only guard self-tests pass | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `202607056100`'s grant rule (a write grant is kept exactly where a sanctioned writer needs it), applied as SPEC-244 applied it to the merge. FIN-8's existing deferred constraint trigger is completed in place. Nothing new is added: no trigger, table, permission, event type or column grant. Rejected:
- revoking UPDATE alone;
- a same-transaction guard;
- column grants;
- a second event producer;
- a reversal workflow.

Added Property: A journal line exists only as part of the entry `app.create_journal_entry` posted it with, and no signed-in user can change, move, re-account or add to a posted line, at any step-up level. Every entry a line leaves or joins is judged at commit, and two transactions changing one entry's lines are serialized on it.

Causal Negative: The pre-repair measurements in Business Reason, at `3c34870`:
- rewrite, retired account, re-parent, append and aal1 at the table;
- the same four over HTTP;
- the emptied entry;
- the two-session write skew.

Positive Test Design: One tenant: a `finance_manager` posts three entries through the RPC, and an `employee` holds no ledger permission. A second tenant's `finance_manager` attacks across the boundary. Account 1100 is retired at its own door. The platform then moves a balanced pair between entries, and the move passes.

Negative Test Design:
- **The door:** at aal2 the finance manager is refused, by the missing grant, a balanced rewrite in another currency, backdated; a move onto the retired account; a re-parent; and an append. At aal1 it is refused both the RPC and the rewrite.
- **Kept refusals:** the employee is refused the RPC, and the rival tenant reads nothing.
- **The balance check:** the platform is refused emptying an entry by moving its lines, after the creation checks still pending in the test transaction are fired, so that the line check alone decides.
- **Records:** every entry still matches its event, and every entry still balances with at least two lines.
- **JE-2:** pinned OPEN.

Non-Empty Population Obligation: Two tenants with active enterprise subscriptions. Tenant one has three users, a seeded chart of accounts and five posted entries; tenant two has its finance manager.

Mutation Obligation: Out of file, record the md5 of a surface covering the RPC's definition, the balance check's definition and the table's ACL. For each mutant:
1. Install it and prove the md5 differs.
2. Run Test 145, or the two-session proof for M5, and record the failing assertions and how many of 19 ran.
3. Restore it and prove the md5 matches the base.

A mutant whose installation is not proven is a harness error, never a kill. A run may stop after its named assertion has failed.

| Mutant | Change | Expected to fail |
| --- | --- | --- |
| M1 | `authenticated` UPDATE restored | 5, 7, 8 |
| M2 | `authenticated` INSERT restored | 9 |
| M3 | the RPC back to SECURITY INVOKER | 3 |
| M4 | the old parent not judged | 16 |
| M5 | the parent lock removed | the two-session proof |

Prototype result: base surface md5 `a0700d7bd49edb3775297e8b2db0caef`. Every installation was proven by a changed md5 and every restoration by the base md5. Test 145 passed again afterwards, and the base two-session proof was refused with a blocking edge.

| Mutant | Failing assertions | Ran of 19 |
| --- | --- | --- |
| M1 | 1, 5, 7, 8, 10, 12 | 15 |
| M2 | 1, 9, 10 | 19 |
| M3 | 2, 3, 5, 7, 8, 10, 12, 15, 16, 17 | 17 |
| M4 | 16, 18 | 19 |
| M5 | both sessions committed, entry emptied | two-session |

M4's first run survived. The RPC postings had left E2's creation check pending in the test's one transaction, and `set constraints all immediate` fired it, so E2 was refused by its own creation check whatever the line rule. Test 145 now fires the pending checks before section 16, and the same mutant is killed. M1's run stops after its named failures, because the landed rewrite makes that flush raise.

Post-Implementation Proof Obligation: All of the following, on the final bytes and through canonical `-Finish`:
- the focused tests, a clean reset, pgTAP Pass A, the declared HTTP suite, pgTAP Pass B and smoke;
- the out-of-file mutations, M5's two-session proof and the pre-repair causal negative;
- the generated artifacts, the four CI-only guard self-tests, repository consistency and `git diff --check`;
- fresh Primary evidence, parity evidence and the Primary ledger check.

## Implementation Steps

1. **Check** that `supabase/migrations/20261008120000_a_journal_line_is_written_only_with_its_entry.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype in `C:\w32`: SHA-256 `74e957d1d1ce2372e1873c2e0413fbe0670161f7d958d76ff263b49f2aa502b0`, md5 `9d047676b3fd927a7a26926b1d6a073c`, 4911 bytes.
   - It holds exactly three statements:
     - `revoke insert, update on public.journal_entry_lines from authenticated;`
     - `alter function app.create_journal_entry(text, date, text, jsonb, uuid) security definer;`
     - `app.enforce_journal_entry_balanced` replaced: same signature, SECURITY DEFINER, empty `search_path`, now judging every entry a line belongs to before and after, sorted, each locked `for no key update` before counting.
   - If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/145_a_journal_line_is_written_only_with_its_entry_test.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `acf4a0498d5e4ecf98d37699f9ada7f6c57b5ab722fbdf4b89cc4a382b340ce2`, `select plan(19);`.
   - Its `-- ATTACK-CLASSES:` line reads `DOOR BUSINESS STATE PRIVILEGE AUTH TENANT OBSERVABILITY INPUT=N/A REPLAY=N/A CONCURRENCY=N/A`, with each `N/A` reason in its header.
   - Then make three LF edits, each byte-identical to the prototype:
     - `supabase/tests/70_journal_entry_balance_test.sql`: assertions 10–14 run as the platform, with a comment saying why; SHA-256 `d2416a2851d6162a1caebacb14832e7f83431334c36d92123a6629865b5c36e0`, still `plan(19)`.
     - `supabase/tests/89_finance_periphery_parent_state_test.sql`: JE-1's assertions 11 and 14 run as the platform; the CLASS inventory and its comment drop the journal pair; SHA-256 `982b0ee60942b67d49d44b4467632990dfd9cbcf8c3125d6ecbd0e825bd36659`, still `plan(21)`.
     - `scripts/verify_journey_branches.ps1`: five JE-3 checks after the ledger block; SHA-256 `c2c2334074952c9f1811070cabdbbbfadd795155d8dd72e07aa5dd04ae6c3509`.
   - If a target carries content other than its `3c34870` bytes or its frozen value, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` already contains a `JE-3` row. If not, apply the prototype's edits, each byte-identical to its frozen value, and nothing else:
   - **Register** (`fd07e8104e5fd80bf43cd112b37a937ab052ddc1acf51faeaefb1afe3debd502`):
     - a 2026-10-08 Slice-32 freshness entry, with the previous one demoted to `Previously:`;
     - rows JE-3 (High) and JE-4 (Medium), each FIXED by SPEC-245 locally with Primary pending and Cert `🛡`;
     - row JE-5 (Medium, OPEN), with its trigger the `journal_entries` slice;
     - one dated sentence each on JE-1, FIN-9 and STEPUP-1.
   - **Disposition** (`b00dce7bd66a750ee20d0552d697b4fce64700f9b646d870f6cc858417b0fc9e`):
     - a freshness entry, with the previous one demoted;
     - coverage 33 of 78 (17 `AUDITED-OPEN`, 45 `NOT-RECORDED`) and the "All 33" line;
     - the `journal_entry_lines` row `AUDITED-OPEN` / `ADVERSARIAL` / SPEC-245 / JE-2, JE-3, JE-4, with its evidence and non-defects.

   If a target carries content other than its `3c34870` bytes or its frozen value, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 values:
   - a clean local reset; the focused Tests 145, 70 and 89;
   - pgTAP Pass A, all six HTTP suites, then pgTAP Pass B without reset; smoke and the plan sum;
   - the mutation evidence, M5's two-session proof and the causal negative;
   - the API-contract and map generators;
   - the scope check, `git diff --check` and repository consistency.

   Treat as expected at this boundary only: an undeployed Primary, the expected pre-deploy repository-consistency issues, and the guard self-test CONTROL failures they cause.

   Read a fresh Primary baseline, read-only:
   - the project URL, the full ordered ledger and the absence of the target migration;
   - the function and structural surfaces;
   - the table's ACL and the two functions' definition md5 and security mode;
   - the tenant, journal-entry, journal-line, chart-account and event counts.

   Record the predicted delta.
5. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 4 and present the Gate-2 package. Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261008120000_a_journal_line_is_written_only_with_its_entry`. If it is absent and deployment is separately authorized:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts, the table ACL and both functions.
   - On an exact match, prove the transmitted text's md5 server-side, then apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row, its stored statement md5 equal to the file's, and no existing target version.
   - Read fresh: the ledger, the function surface and all ten structural surfaces; the table ACL; both functions' definition, security mode, `search_path` and ACL; the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with 458 HTTP assertions last passed on the Step-4 date.
   - Confirm that `supabase/tests` holds 145 files whose literal `plan(N)` values sum to 2657, then set `Suite **145 files / 2657 assertions**`; if either differs, stop.
   - Set Batch 6 coverage to 33 of 78, all thirty-three at `ADVERSARIAL`.
   - Mark JE-3 and JE-4 `DEPLOYED` with Cert `✅`, worded without a date beneath the register's freshness line.
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
     - set `Last Completed` to SPEC-245 / Slice 32;
     - set `Current Module` to Foundation Completion Programme Batch 6 resuming at Slice 33;
     - set `Next capability` to **Foundation Completion Programme — Batch 6 Slice 33**, naming the measured first target, followed by the Phase-8 order roadmap 32 owns, keeping its closed-chapter and standing-fact sentences;
     - keep the manifest within 7000 characters;
     - regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate with `scripts/publish_candidate.ps1` and require exact-SHA candidate CI.
   - Promote the same accepted SHA, require main CI, and run `-Certify` for `REMOTE_CERTIFY: READY`.
   - Verify synchronized clean refs.

## Acceptance Criteria

- [ ] `authenticated` holds SELECT and neither INSERT, UPDATE nor DELETE on `journal_entry_lines`. A CREATE_JOURNAL_ENTRY holder at aal2 or aal1 cannot rewrite, re-account, move or append to a posted line, in pgTAP or over HTTP.
- [ ] `app.create_journal_entry` is SECURITY DEFINER with an empty `search_path`. It still posts, still charges permission and step-up, and still refuses an employee and an unbalanced entry.
- [ ] Every posted entry still says what its `journal_entry_created` event says it was.
- [ ] No writer, the platform included, can leave an entry with fewer than two lines, unbalanced or at zero by moving its lines; a move that leaves both entries balanced passes. Two transactions emptying one entry from two sides cannot both commit.
- [ ] Tests 70 and 89 keep their FIN-8 and JE-1 purpose, asked of the platform. JE-2 is pinned OPEN.
- [ ] Mutants M1 to M5 are each killed, with installation and restoration md5-proven. The causal negative is recorded.
- [ ] JE-3 and JE-4 are fixed and deployed in the register, JE-5 is OPEN with its trigger, and JE-1, FIN-9 and STEPUP-1 carry their dated sentences. `journal_entry_lines` is `AUDITED-OPEN` / `ADVERSARIAL` in the disposition record, and coverage is 33 of 78. No other surface's row changed. JE-2, DC-11, BOOK-11, BOOK-12, PAY-5, CONV-9 and CONV-10 are unchanged.
- [ ] The migration, the three tests, the HTTP script and the two Step-3 documents matched their frozen SHA-256 values when applied.
- [ ] Primary, the recorded evidence, the manifest (242 migrations; 145 files / 2657 assertions; 458 HTTP assertions), the API contract and `ai-map.json` agree.
- [ ] The manifest names Batch 6 Slice 33 and its measured target as the next capability, with no Active Change Request.
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

- **EARN IT.** Every attack was reproduced on the pre-repair schema, in pgTAP and over HTTP, and the lock was earned by a two-session schedule that emptied an entry without it.
- **WORTH IT.** One revoke, one `ALTER FUNCTION` and one trigger function completed in place. No new table, trigger, permission, event or column grant.
- **SIMPLIFY IT WITHOUT WEAKENING.** The redundant door is removed rather than defended field by field. Posted history keeps one writer, and FIN-8's own check now judges every entry a change touches.
- **Owner delegation (2026-10-08, Slice-32 directive).** The owner directed this slice to proceed through repository governance to a Primary Gate-2 stop if a migration is earned, then through publication and synchronization. Approving this contract does not authorize any Primary write.
- **Deliberately not changed:** JE-2 and DC-11; JE-5 and the `journal_entries` header; canon 07 and 31; FIN-9's emitter question; the n8n workflow and Phase 8; BOOK-11, BOOK-12, PAY-5, CONV-9 and CONV-10; the registered worktrees `owt/p2` and `C:\w234`.
