# Change Request — SPEC-278

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[x] Cancelled

## Objective

Batch 6 Slice 42 makes a chart account's code and type fixed once a journal line is posted to it, and makes the table door charge the step-up the seed RPC charges (COA-1, COA-2).

## Business Reason

- **Selection.** `scripts/batch6_select_target.ps1` at `4347817`, on the live local catalog, ranks `chart_of_accounts` first: Exposure 7, coverage 38, NOT-RECORDED (runner-up `notification_deliveries` 7/42). It is the target the manifest names.
- **Execution strategy (owner-authorized 2026-10-13).** Batch 6 runs one slice per contract in the selector's order, with one evidence-backed exception. `user_branch_assignments` and `user_permission_grants` share one finding (USR-3), one defining migration (`202607059800`) and one repair, so they are planned as one contract when the selector first reaches either. `chart_of_accounts` shares its root cause with no remaining surface, so this contract covers it alone.
- **The rule.** A chart account is what a journal line means.
  - `app.create_journal_entry` resolves each line by the account's code.
  - The account's type classifies the money posted to it.
  - Canon 07 and 30 correct a posted entry by a reversal, never by mutation (JE-3, JE-5).
  - Canon 14 lets a company customize its chart "according to permissions".
  - The sanctioned writer, `app.seed_default_chart_of_accounts`, charges `app.authorize('CREATE_JOURNAL_ENTRY')`, which includes step-up.
  - `authenticated` holds INSERT and UPDATE on the table, and its policies ask only `app.has_permission`.
- **Measured at `4347817`** on the local stack, in rolled-back transactions, as a `finance_manager` at `aal1`, where both RPCs refuse with `multi-factor authentication required for this role`:
  - **COA-1 (High).** After a 1000 sale was posted to cash 1000 and revenue 4000, the account 4000 was retyped to `expense` and recoded to `4999`. The posted credit then read as an expense. Account 5000 (Cost of Sales) then took the code `4000`, so the RPC's next "4000" posting would land on an expense account. No event recorded any of it.
  - **COA-2 (Medium).** Every write above was made at `aal1`. This is STEPUP-1's member on this table, reproduced and consequence-classified by COA-1.
- **Consumers of the attributes that stay editable**, read from the catalog (every function, view, materialized view, policy and trigger) and the repository (Edge Functions, scripts, canon), 2026-10-13:
  - `name`: no database object reads it. It is exposed only through `scope_read` and written by the seed. Renaming a used account changes a label, which is canon 14 customization.
  - `parent_account_id`: no database object reads it except its own foreign key. No ledger rollup exists: canon 14 lists the balance sheet and income statement, `MASTER_DOMAIN_CATALOG.md` marks the statement machinery `[D]` (designed, not built), and no `reporting` view touches the ledger. Re-parenting reinterprets nothing today.
  - `is_active`: read only by `app.create_journal_entry` and `app.guard_parent_state_allows_write`, at write time, to refuse a NEW posting to a retired account (JE-1). Posted lines are untouched. `89_...` and `145_...` pin retiring as legitimate.
- **Measured and not repaired, recorded as positions.** These observations carry no measured consequence, and one is governed by a ratified decision:
  - `account_type` accepted `banana`. ADR-0006 stores type codes as plain text and makes hard database enforcement optional per column. Canon 30 allows it where a column genuinely warrants it, justified in that column's own migration, by a catalog validation trigger or a constant type column with a composite FK. This column has no catalog family, `202607051300` excluded it by name, and `reports/future-backlog.md` closed it as NOT A GAP. Nothing reads `account_type` today, so enforcement is not warranted now. **Reopening trigger:** the first consumer of the account type (financial statements).
  - An account that is its own parent and a parent cycle were stored. Nothing reads the hierarchy. **Reopening trigger:** the first consumer of the hierarchy (financial statements).
  - A blank name was stored, and nothing reads `name`.
  - **A blank code is consumed by `app.create_journal_entry`, measured 2026-10-13 in one rolled-back transaction at `aal2`:**
    - before any `''` account exists, a line with `"account_code": ""` is refused `unknown or inactive chart account code`, as are a missing key and `" "`;
    - the same finance manager then created a `''` account at the door; a second was refused by the (tenant, code) key;
    - a posting with `"account_code": ""` then succeeded: one balanced entry, one line on that account, one `journal_entry_created` event;
    - a missing key and `" "` were still refused, and recoding the used `''` account was refused by COA-1.
  - The consequence of a blank code is bounded:
    - only the tenant's own CREATE_JOURNAL_ENTRY holder with step-up, the authority that posts, can create the selector;
    - it is unique per tenant, and the posted money sits on a real account with a real type;
    - the entry is balanced and recorded, and the code is fixed once used;
    - what changes is that an empty input selects that account instead of being refused, which needs a client that submits a blank field.
  - **Reopening trigger** for the blank code: the first client application that submits journal lines (`ENABLE-CLIENT-WRITES`).
- **Swept and found sound, pinned rather than changed:**
  - an `employee` without CREATE_JOURNAL_ENTRY is refused at the door;
  - a rival tenant's finance manager reads none of the chart and cannot write into it;
  - moving an account to another tenant is refused by RLS;
  - `authenticated` holds no DELETE;
  - one code per tenant (`chart_of_accounts_tenant_code_key`) and a tenant-qualified parent key.
- **Also recorded:**
  - Canon 27 registers no chart-account event. The facts a posted line depends on are enforced rather than logged, and the remaining edits are configuration.
  - `is_system_default` and `created_at` are caller-supplied, and nothing reads either except the seed (searched).
- **Latent:** Primary `vrvtsxexkiiiivlkdxzp` holds 0 tenants, 0 chart accounts and 0 journal lines (read 2026-10-13), so no existing row is affected and no data repair is needed.

## Risks

- **The door now charges step-up.** An `aal1` session holding CREATE_JOURNAL_ENTRY can no longer customize the chart. That is the seed RPC's rule. The two existing tests that retire an account (`89_...` assertion 12, `145_...`) run at `aal2` and pass on the prototype.
- **`10_grant_model_test` assertion 9's list grows from ten to eleven.** That ceiling "may fall further and must never rise" unless the author justifies it.
  - `guard_write_capability` was available and was not used. It has no mapping for this table, so using it means replacing a 230-line SECURITY DEFINER function that serves 28 tables, and also moving `58_...`'s 28-table count, to add one line.
  - The justification is written into the test: the charge is unconditional for every signed-in caller. Its one exemption, the session-less platform write, is pinned by test 157 assertion 20 and by the injection in assertions 21 and 22.
- **Mechanism substitution (`MASTER_EXECUTION_PLAN.md`, Batch 6 method).** `29_...`'s employee insert into `chart_of_accounts` expects 42501 with no message. It is now refused by the guard's `app.authorize` before RLS, for the same missing permission, so the assertion still measures the rule it names. No other existing assertion's refusal moves (full suite measured).
- **Concurrency is proven outside pgTAP.** A posting in flight against a retype needs two live sessions. The two-session harness's results are in Notes, and the row lock is recorded honestly as mutant M4.
- **Primary deployment is a separate exact-byte authorization.** Approval of this contract does not authorize it.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-278-a-used-ledger-account-keeps-its-meaning.md`
- `supabase/migrations/20261013120000_a_used_ledger_account_keeps_its_meaning.sql`
- `supabase/tests/157_a_used_ledger_account_keeps_its_meaning_test.sql`
- `supabase/tests/10_grant_model_test.sql`
- `ENGINEERING_METHOD.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607041800_create_finance_foundation_tables.sql`
- `supabase/migrations/202607051300_complete_catalog_enforcement.sql`
- `supabase/migrations/202607059800_capability_grants_are_per_user_not_only_per_role.sql`
- `supabase/migrations/20260926140000_manifest_freeze_cannot_be_left.sql`
- `supabase/tests/29_financial_write_authority_test.sql`
- `supabase/tests/58_write_grants_and_config_capability_test.sql`
- `supabase/tests/89_finance_periphery_parent_state_test.sql`
- `supabase/tests/145_a_journal_line_is_written_only_with_its_entry_test.sql`
- `supabase/tests/146_a_posted_journal_entry_is_never_rewritten_test.sql`
- `scripts/verify_database.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `_ORVION_CANONICAL/14_finance_rules.md`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/30_database_conventions.md`
- `reports/architecture-decision-records.md`
- `reports/future-backlog.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/14_finance_rules.md` (Chart Of Accounts); `_ORVION_CANONICAL/24_entity_registry.md` (Chart Of Account); `_ORVION_CANONICAL/30_database_conventions.md` (physical enforcement of status/type codes)
- `reports/architecture-decision-records.md` (ADR-0006); `reports/future-backlog.md` (the closed `account_type` row)
- `reports/master/MASTER_GAP_REGISTER.md` (JE-1, JE-3, JE-5, STEPUP-1, USR-3); `reports/master/MASTER_SURFACE_DISPOSITION.md`; `reports/master/MASTER_EXECUTION_PLAN.md`, Batch 6 method, EC-1…EC-11 and the Action registry
- `supabase/tests/10_grant_model_test.sql` assertion 9 and its comment; `supabase/tests/146_a_posted_journal_entry_is_never_rewritten_test.sql` (the fixture shape)
- Current local `app.create_journal_entry`, `app.seed_default_chart_of_accounts`, `app.authorize`, `app.guard_parent_state_allows_write`, `app.forbid_used_account_redenomination` (the precedent for "fixed once used")

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
- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A chart account's code and type are fixed once a journal line is posted to it | `app.create_journal_entry` (resolves by code and `is_active`); `app.guard_parent_state_allows_write` (JE-1 at the door); `journal_entry_lines` (composite FK) | WRITE | Prototype: a clean reset of the `4347817` local stack plus the migration (253 migrations), applied from a disposable clone. The migration is SHA-256 `8b99747e6ab7afbc0ab7b600e7ada7413835252398bc8097a8b03b739205c0cc`, md5 `635d504d4069cafb52bd113112126a78`, 3858 bytes, LF, ASCII. A retype and a recode of a posted account are refused 23514 for the finance manager at `aal2` and for a session-less caller. Rename, retire, re-parent, and the recode or retype of an unused account still land. |
| `name`, `parent_account_id` and `is_active` stay editable on a used account | every catalog object and repository consumer (Business Reason) | UNAFFECTED | No reader of `name` or of the hierarchy exists. `is_active` is read only to refuse a new posting (JE-1), and `89_...` and `145_...` still pass. |
| `account_type` stays plain text | ADR-0006; `202607051300`'s exclusion; the closed backlog row | UNAFFECTED | No CHECK, trigger or catalog family is added. The guard constrains only a used account's type changing, as `app.forbid_used_account_redenomination` does for `financial_accounts`. |
| The door charges `app.authorize('CREATE_JOURNAL_ENTRY')` for every signed-in caller | `scope_insert`/`scope_update` RLS (unchanged); `29_...`, `89_...`, `145_...`; the HTTP suites | WRITE | Prototype: `aal1` insert and update are refused 42501 `multi-factor authentication required for this role`. The `aal2` retirements in `89_...` and `145_...` pass. `29_...`'s employee refusal keeps 42501 for the same missing permission. HTTP 35/0, 85/0, 122/0. |
| Test 10 assertion 9's bespoke-guard list grows from ten to eleven, with its justification | `supabase/tests/10_grant_model_test.sql` | WRITE | The edit adds `chart_of_accounts` to the array and states why `guard_write_capability` was not used. LF blob `36dfceb92dbc0c707a0418e5ec2a269f9025f487`, SHA-256 `61f4e6d4069bd99b3fe91ea63e84f4fc838169d68eeb0ffdd87c5ec4ae33465c`, 21290 bytes; from HEAD blob `814f1e4dae0ac98b9fb0059ace86167463cff130`. Test 10 is 9/9 on the prototype; without the edit, assertion 9 fails (measured). |
| Test 157 | `supabase/tests` | WRITE | SHA-256 `e501187f4514f7ebb6843799ccb4229e477c1298640af0bac8b3e81a57982608`, md5 `6d4e5eb1f154a921c349e5831e5f567a`, `plan(25)`, 13638 bytes, LF, ASCII: 25/25 on the prototype. |
| Other tests and the suite | the full pgTAP suite | VERIFY | On the prototype with the pinned CLI 2.120.0: Pass A `Files=157, Tests=2994`, PASS; the three HTTP suites; Pass B 2994, PASS. 157 files whose literal `plan(N)` values sum to 2994. |
| Smoke | `scripts/verify_database.sql` | VERIFY | On the prototype: `ALL CHECKS PASSED (78 tables, … 71/623 catalog, …)`. No table, catalog value, policy, constraint or transition is added. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | Measured on the prototype: functions 332 (+1, `app.guard_chart_account`, not executable by `authenticated` or `anon`), triggers 319 (+1, `chart_of_accounts_guard`), `_combined` 3136 (+2). Constraints (527), policies, grants, columns, views, indexes, status transitions and RLS are unchanged. Step 9 writes Primary values only from fresh post-deploy readings. |
| Client API | `MASTER_API_CONTRACT.md` (Check L3) | VERIFY | No RPC is added, removed or changed; the generator is predicted to leave it byte-identical. It is in Write Scope because a migration makes Check L3 apply. |
| The lesson this slice's own proofs taught | `ENGINEERING_METHOD.md` §3 | WRITE | One bullet after "A failed run is not automatically a finding", per §3 "A lesson is promoted, never only remembered". LF blob `62580e36a61b84b9a5282377e0a9fa3571b03669`, SHA-256 `58989bcb3c84ef94f9a3c7de0d17bb565cc591600fd1e934632d8f47d6e6483c`, 36525 bytes; from HEAD blob `b726938d67d9c1f151facce3e69c245179356620`. No heading changes, so no pointer moves. |
| Measured state that moves | manifest (`Live state`, suite figure, `Last Completed`, `Current Module`, `Next capability`); `primary-ledger-evidence.json`; `ai-map.json` and `repository-index.md` (one generator, Check 7) | WRITE | 252 → 253 migrations, latest `20261013120000`; 156 → 157 files and 2969 → 2994 assertions; coverage 42 → 43 of 78. Catalog (71/623), HTTP (464), tables (78), views (8) and client RPCs (80) do not move. |
| COA-1 and COA-2 fixed; STEPUP-1's member closed; the surface recorded | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24, 25, 29 | WRITE | The `COA-` prefix is unused at `4347817`. Test 157's `-- ATTACK-CLASSES:` line declares eight classes with STATE and REPLAY `=N/A`, each with its reason, and carries negative assertions, so Check 24 admits `ADVERSARIAL`. New rows have Owner `—` and are settled, so Check 29 needs no registry row. The recorded positions are not findings. STEPUP-1 stays open for its other members. Coverage 43 recorded: 19 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 35 `NOT-RECORDED`. |
| CI-only guard self-tests and repository consistency | `scripts/test_*_guard.ps1` (four); `scripts/check_repository_consistency.ps1` | VERIFY | Measured in the rehearsal clone with Steps 1–4 committed: consistency reports exactly the six measured-state issues (252 vs 253 migrations, latest, ledger fingerprint, 156 vs 157 files, assertion count, the Primary-evidence record). The primary-ledger and cold-start self-tests are predicted to fail only their CONTROL and restore cases because of it. These are not waived: Step 9 makes them true and Step 10 requires them green. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 8 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused tests, pgTAP A/B, the declared HTTP suites, smoke, the mutants and the race | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 6 |
| COA-1, COA-2 and the disposition describe the local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 6 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 9 | Step 10 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 2 | Step 9 | Step 10 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 9 | Step 10 |
| The four CI-only guard self-tests pass | BEFORE_COMPLETION | Step 1 | Step 9 | Step 10 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: The RLS policies charge `app.has_permission('CREATE_JOURNAL_ENTRY')` without step-up. `app.create_journal_entry` and `app.guard_parent_state_allows_write` refuse a posting to an inactive account (JE-1) and never ask what an account meant when a line was posted. `app.forbid_used_account_redenomination` protects `financial_accounts` alone. `guard_write_capability` has no mapping for this table, and Risks explains why it was not extended. This contract reuses the `financial_accounts` "fixed once used" idiom, PAY-6's 23514 for integrity, and the platform exemption every capability guard keeps (canon 35 principle 6).

Added Property: Once a journal line is posted to a chart account, its code and type never change for any caller, and a posting in flight is waited for. Every signed-in write at the door needs CREATE_JOURNAL_ENTRY with step-up.

Causal Negative: These are the pre-repair measurements in Business Reason, at `4347817`.
- On a clean reset of the unrepaired 252 migrations, test 157 fails assertions 4, 5, 6, 11, 14, 15 and 19, then aborts at assertion 21, whose `drop trigger chart_of_accounts_guard` names a trigger that does not exist.
- Assertion 11 fails only because assertion 6 has already freed the code `1000`.
- With only the row lock removed from the prototype, two live sessions stored a posted revenue line under an `expense` account.

Positive Test Design: One tenant has a `finance_manager` who seeds the default chart and posts 1000/1000 through the RPC at `aal2`, and an `employee`. A rival tenant has its own finance manager. Positive controls:
- the seed writes ten accounts;
- the posting lands;
- the used revenue account is renamed and the used cash account re-parented;
- an unused account is recoded and retyped;
- an account is retired;
- a session-less caller adds an account;
- the posted entry's meaning and its one event are unchanged at the end.

Negative Test Design:
- **Meaning (COA-1):** a retype, a recode, and a combined recode, retype and rename of a posted account are refused 23514, also for a session-less caller.
- **Step-up (COA-2):** an `aal1` insert and update are refused 42501, beside the seed RPC's own `aal1` refusal.
- **Input:** a duplicate code is refused 23505.
- **Authority and tenancy:** the employee's insert, and the rival's read and insert, are refused.
- **Privilege:** the guard is not executable by `authenticated` or `anon`.
- **Injection:** with the guard dropped in a savepoint, the `aal1` retype lands; after rollback it is refused again.

Non-Empty Population Obligation: The tenant has two users with roles, ten seeded accounts and one posted entry with two lines; the rival has a user. Each refusal is asserted by exact SQLSTATE and, for the guard's own refusals, its exact message. Assertion 2 counts the ten accounts, assertion 23 compares the posted lines' meaning by value, and assertion 24 reads the one event by its contents.

Mutation Obligation: Each mutant replaces the guard, or grants it, on the prototype stack. The run proves the mutant installed from a changed fingerprint, runs test 157, records the failing assertions, then restores. It proves the restoration byte-equal before the next mutant: `md5(prosrc)` `6cafcfacc4ef4648df5af67e5952dbdb`, 4 constraints, no `authenticated` EXECUTE, and 25/25. A mutant not proven installed is a harness error, never a kill.

| Mutant | Change | Failed on the prototype |
| --- | --- | --- |
| M1 | the used-account check removed | 4, 5, 6, 11, 19, 22, 23 |
| M2 | `code` left out of the fixed pair | 5, 19, 22, 23 |
| M3 | `account_type` left out | 4, 19, 22, 23 |
| M4 | the row lock removed | none in pgTAP; killed by the two-session race |
| M5 | the capability charge removed | 14, 15 |
| M6 | step-up dropped (`has_permission` only) | 14, 15 |
| M7 | the platform path charged | 19, 20 |
| M8 | integrity exempted for the platform | 19, 23 |
| M9 | the guard granted to `authenticated` | 25 |

Prototype result: all nine were killed as listed, M4 only by its race, and every restoration was proven byte-equal and 25/25.

Post-Implementation Proof Obligation: All of the following, on the final bytes and through canonical `-Finish`, from the main checkout with the pinned CLI:
- the focused test, a clean reset, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke;
- mutants M1–M9, the two-session race with and without the row lock, and the pre-repair causal negative;
- the generated artifacts, the four CI-only guard self-tests, repository consistency and `git diff --check`;
- fresh Primary evidence, parity evidence and the Primary ledger check.

## Implementation Steps

1. **Check** that `supabase/migrations/20261013120000_a_used_ledger_account_keeps_its_meaning.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `8b99747e6ab7afbc0ab7b600e7ada7413835252398bc8097a8b03b739205c0cc`, md5 `635d504d4069cafb52bd113112126a78`, 3858 bytes, blob `94b594c1408d9c33d2a2cbb6209eb57c11aa8995`.
   - After a comment block stating the rule and the measurements, it creates `app.guard_chart_account()` (SECURITY DEFINER, empty `search_path`, commented, PUBLIC revoked) with its BEFORE INSERT OR UPDATE trigger `chart_of_accounts_guard`. It adds no constraint.
   - If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/157_a_used_ledger_account_keeps_its_meaning_test.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `e501187f4514f7ebb6843799ccb4229e477c1298640af0bac8b3e81a57982608`, md5 `6d4e5eb1f154a921c349e5831e5f567a`, 13638 bytes, blob `bf0246be997e4f62faf55f453115c1444e4debaa`, `select plan(25);`.
   - Its `-- ATTACK-CLASSES:` line reads `AUTH TENANT DOOR BUSINESS INPUT PRIVILEGE CONCURRENCY OBSERVABILITY STATE=N/A REPLAY=N/A`.
   - If the target exists with different bytes, stop.
3. **Check** the blob of `supabase/tests/10_grant_model_test.sql`.
   - If it is `36dfceb92dbc0c707a0418e5ec2a269f9025f487`, record Already Applied.
   - If it is `814f1e4dae0ac98b9fb0059ace86167463cff130`, make it `36dfceb92dbc0c707a0418e5ec2a269f9025f487`. The edit adds `'chart_of_accounts'` first in assertion 9's array, changes `TEN` to `ELEVEN`, appends one sentence to the assertion's description, and adds the "IT WENT FROM TEN TO ELEVEN" comment paragraph before the section's closing rule.
   - Otherwise stop.
4. **Check** the blob of `ENGINEERING_METHOD.md`.
   - If it is `62580e36a61b84b9a5282377e0a9fa3571b03669`, record Already Applied.
   - If it is `b726938d67d9c1f151facce3e69c245179356620`, make it `62580e36a61b84b9a5282377e0a9fa3571b03669`: one §3 bullet, "A harness result is evidence only after every participant's own output is read", directly after the bullet ending "Establish which it is before recording anything.".
   - Otherwise stop.
5. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` already contains a `COA-1` row. If not, make these edits and nothing else:
   - **Register:**
     - a 2026-10-13 Slice-42 freshness entry, with the previous one demoted to `Previously:`;
     - new rows COA-1 (High) and COA-2 (Medium), placed after RCPT-4, each leading `FIXED … locally; Primary deployment pending`, with Cert `🛡`, Owner `—`, this contract as session, and the measurements above;
     - in STEPUP-1's status cell, one sentence after its `journal_entry_lines` sentence: `chart_of_accounts` was audited in Batch 6 Slice 42 (SPEC-278), its member reproduced as COA-2 and closed, and it no longer meets the criterion, because `app.guard_chart_account` charges `app.authorize`.
   - **Disposition:**
     - a freshness entry, with the previous one demoted;
     - coverage 43 of 78 (19 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 35 `NOT-RECORDED`) and the "All 43" line;
     - the `chart_of_accounts` row `AUDITED` / `ADVERSARIAL` / SPEC-278 / COA-1, COA-2.
     - Its text gives the evidence, the consumers of `name`, `parent_account_id` and `is_active`, and the swept non-defects.
     - It also gives the recorded positions, each with its reopening trigger: the `account_type` vocabulary under ADR-0006 and the hierarchy ("the first consumer of the account type or the hierarchy"), and the blank code with its measured consequence ("the first client application that submits journal lines"). It also records the blank name, the event vocabulary and the two unread columns.

   If a target carries content other than its `4347817` bytes, stop.
6. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 values, all from the main checkout with the repository's pinned CLI:
   - a clean local reset; test 157 and the focused tests 10, 29, 89, 145 and 146;
   - pgTAP Pass A, the three declared HTTP suites, then pgTAP Pass B without reset; smoke and the plan sum;
   - mutants M1–M9 and the two-session race (with the row lock, and with only it removed), with each restoration proven byte-equal;
   - the causal negative on a clean reset with the migration held aside;
   - the local structural fingerprints of `scripts/parity_surface.sql`, before and after the migration;
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
   - the triggers and constraints of `chart_of_accounts`;
   - the tenant, chart-account and journal-line counts.

   Record the predicted delta.
7. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 6 and present the Gate-2 package. Approval of this contract does not authorize deployment.
8. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261013120000_a_used_ledger_account_keeps_its_meaning`. If it is absent and deployment is separately authorized:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts and the triggers and constraints of `chart_of_accounts`.
   - On an exact match, prove the transmitted text's md5 server-side, then apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row, its stored statement md5 equal to the file's, and no existing target version.
   - Read fresh: the ledger, the function surface and all ten structural surfaces; the triggers and constraints of `chart_of_accounts`; the guard's definition, security mode and ACL; the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
9. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with the catalog figure `71/623` and 464 HTTP assertions unchanged.
   - Confirm that `supabase/tests` holds 157 files whose literal `plan(N)` values sum to 2994, then set `Suite **157 files / 2994 assertions**`. If either differs, stop.
   - Mark COA-1 and COA-2 `DEPLOYED` with Cert `✅`, worded without a date beneath the register's freshness line.
   - Regenerate `MASTER_API_CONTRACT.md`, `ai-map.json` and `repository-index.md` (stored LF) with the canonical generators.
   - Run the four `scripts/test_*_guard.ps1` and require each to pass.
   - Set the Runtime Checkpoint to DONE.
   - Run `check_primary_ledger.ps1`, `check_database_parity_evidence.ps1`, repository consistency and `git diff --check`.

   If Primary is unproven, stop.
10. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
    - Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`.
    - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, do all of the following in the Complete commit:
      - transition to Complete, tick the Acceptance Criteria and the Review Gate, and clear `Active Change Request`;
      - run `scripts/batch6_select_target.ps1` and record its Top-12;
      - set `Last Completed` to SPEC-278 / Slice 42;
      - set `Current Module` to Foundation Completion Programme Batch 6 resuming at Slice 43;
      - set `Next capability` to **Foundation Completion Programme — Batch 6 Slice 43**, naming the measured first target, followed by the existing Phase-8 order, closed-chapter and standing-fact sentences unchanged;
      - keep the manifest within 7000 characters;
      - regenerate `ai-map.json` and `repository-index.md` LF.
    - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate with `scripts/publish_candidate.ps1` and require exact-SHA candidate CI.
    - Promote the same accepted SHA, require main CI, and run `-Certify` for `REMOTE_CERTIFY: READY`.
    - Verify synchronized clean refs.

## Acceptance Criteria

- [ ] A retype or recode of a chart account that has a posted journal line is refused (23514) for every caller, the platform path included; renaming, retiring and re-parenting it, and recoding or retyping an unused account, still succeed.
- [ ] A signed-in insert or update at the `chart_of_accounts` door at `aal1` is refused 42501 `multi-factor authentication required for this role`; a session-less insert succeeds.
- [ ] `app.guard_chart_account` is SECURITY DEFINER with an empty `search_path` and is executable by neither `authenticated` nor `anon`; the migration adds no constraint and no catalog enforcement to `account_type`.
- [ ] Mutants M1–M9 are each killed, M4 by its race, with installation and byte-equal restoration proven, and the causal negative is recorded.
- [ ] `10_grant_model_test` assertion 9 names eleven tables, `chart_of_accounts` among them, with the stated justification.
- [ ] `ENGINEERING_METHOD.md` §3 carries the "A harness result is evidence only after every participant's own output is read" bullet.
- [ ] COA-1 and COA-2 are fixed and deployed in the register, and STEPUP-1 records its `chart_of_accounts` member closed; no other row changed.
- [ ] `chart_of_accounts` is `AUDITED` / `ADVERSARIAL` in the disposition record, with its recorded positions and their reopening trigger, and coverage is 43 of 78. No other surface's row changed.
- [ ] The migration, test 157, test 10 and `ENGINEERING_METHOD.md` matched their frozen values when applied.
- [ ] Primary, the recorded evidence, the manifest (253 migrations; 71/623 catalog; 157 files / 2994 assertions; 464 HTTP assertions), the API contract, `ai-map.json` and `repository-index.md` agree. The four CI-only guard self-tests and repository consistency pass.
- [ ] The manifest names Batch 6 Slice 43 and its measured target as the next capability, with no Active Change Request.
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-10-14 — Gate 1 approval and Steps 1–5 applied

- **Authority:** the owner's 2026-10-14 authorization approves Gate 1 for the exact Draft blob `57cab679be3b35c8f4f2fe2666c73fd94627ba97`, SHA-256 `2288676b53a57b412e8be7e11add7ac4b82d7792d56f0098d7f29038ba4373aa`, 37416 bytes, LF, base `4347817ff74c8de720836e2d4915a9d6cebcf27b`, Write Scope the 12 files above. Earlier Draft identities are superseded and not approved. **Gate 2 is not authorized.**
- **Verified before acting:**
  - HEAD and `origin/main` were both `4347817`, and the untracked Draft hashed to the approved blob, SHA-256 and size;
  - the word diff from the previously reviewed Draft `f78f65177f6b84f06593cb083de729ddf28a9da5` touches only the documented corrections: the blank-code measurement, its consequence and reopening trigger, and the ADR-0006 wording in Business Reason; the Step 5 disposition text; and the Notes revision paragraph. No Write Scope path, Step pin or hash changed.
- **Lifecycle:** Draft `b5e0568` (blob `57cab67`), Approve `5f3b559` (`ai-map.json` regenerated, blob `1397cd2`, as rehearsed), range Gate from `4347817` READY with no blocker, Begin `f923c0d` (contract blob `43dcea4`, as rehearsed).
- **Steps 1–2.** The migration and test 157 were absent and were created LF and ASCII from their pinned blobs: migration `94b594c1…`, SHA-256 `8b99747e6ab7afbc0ab7b600e7ada7413835252398bc8097a8b03b739205c0cc`, md5 `635d504d4069cafb52bd113112126a78`, 3858 bytes; test 157 `bf0246be…`, SHA-256 `e501187f4514f7ebb6843799ccb4229e477c1298640af0bac8b3e81a57982608`, md5 `6d4e5eb1f154a921c349e5831e5f567a`, 13638 bytes, `plan(25)`, with the stated `ATTACK-CLASSES` line.
- **Steps 3–4.** `10_grant_model_test.sql` was `814f1e4…` and became `36dfceb92dbc0c707a0418e5ec2a269f9025f487`; `ENGINEERING_METHOD.md` was `b726938…` and became `62580e36a61b84b9a5282377e0a9fa3571b03669`.
- **Step 5.** The register and the disposition record were at their `4347817` blobs (`7249a51…`, `c5ad093…`).
  - Register: a Slice-42 freshness entry, with SPEC-277's entry demoted to `Previously:`; rows COA-1 (High) and COA-2 (Medium) after RCPT-4, each leading `FIXED … locally; Primary deployment pending`, with Cert `🛡` and Owner `—`; and STEPUP-1's `chart_of_accounts` sentence.
  - Disposition: the freshness entry; coverage 43 of 78 (19 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 35 `NOT-RECORDED`); the "All 43" line; the `chart_of_accounts` row `AUDITED` / `ADVERSARIAL` with its evidence, consumers, swept non-defects and the four recorded positions with their reopening triggers.
  - **The blank-code trigger is recorded, not linked.** The row names `ENABLE-CLIENT-WRITES`, a boundary of the Action registry. `scripts/readiness_population.ps1` (Check 29) derives its members only from open register findings, `AUDITED-OPEN` or `PARTIAL` surfaces, open decisions, `NOT-RECORDED` surfaces and the backlog's "Live deferred items" rows. An `AUDITED` row's position is none of these, so crossing the boundary will not surface it automatically. The governed linkage is a backlog row, and `reports/future-backlog.md` is outside this Write Scope, so it is left to a separate contract.
- **Checks:** `git diff --check` is clean, and only Write Scope paths changed. Repository consistency reports exactly the six predicted pre-deploy items (252 vs 253 migrations, the latest migration, the ledger fingerprint, 156 vs 157 files, 2969 vs 2994 assertions, RECOVER-1). Check 29 passes.
- **Not committed until deployment.** A commit of Steps 1–5 was refused by the pre-commit repository guard on those six items, which clear only at Step 9. As SPEC-268 did (`04d117e`), the implementation stays in the working tree and only this contract's Execution Log is committed at the readiness gate.

### 2026-10-14 — Pre-deploy readiness gate (Step 6)

From the main checkout at HEAD `f923c0d`, with the pinned CLI 2.120.0 (SPEC-271) and `auto_expose_new_tables = false`, under one logged script, no other repository script running:
- **Causal negative.** A clean reset with the migration held aside gave 252 migrations, latest `20261012120000`, no guard, triggers `chart_of_accounts_enforce_subscription_write_gate` and `chart_of_accounts_set_updated_at`, 4 constraints. Test 157 failed assertions 4, 5, 6, 11, 14, 15 and 19, as predicted. At the injection block, `drop trigger chart_of_accounts_guard` failed because the trigger does not exist, the transaction aborted, and the plan never reached 24–25. Assertion 22 printed the damage itself: the posted entry read `1999/expense` and `4999/expense` instead of `1000/asset` and `4000/revenue`. The migration was put back at its pinned blob `94b594c1…`.
- **Fingerprints.**
  - Before the migration, local equals Primary: functions `e6a65849bc390360dcb53b2be4f1a0b8`/331, triggers `d0b98a16e51bb805a93e14737cd5e1b3`/318, constraints `e669286c961025cb49688862286338ed`/527, `_combined` `02dcc5a1076506289a6f7ff81894fb4d`/3134.
  - After a clean reset with it: 253 migrations, ledger `b144bdf0f5a31ac66a0f0a723fb009bc` (equal to the files), latest `20261013120000`; functions `2cd20c3fea8247598eb9b2bbb559f2ca`/332 (+1), triggers `9b53576506088625f67f8156f122bd44`/319 (+1), `_combined` `56625ae4118e1ddc85bab99114b17899`/3136. Policies, constraints, grants, columns, views, indexes, status transitions and RLS are unchanged. The Check L2/P2 function surface is `2cd20c3fea8247598eb9b2bbb559f2ca`/332.
  - `app.guard_chart_account`: `md5(prosrc)` `6cafcfacc4ef4648df5af67e5952dbdb`, SECURITY DEFINER, `search_path=""`, executable by neither `authenticated` nor `anon`; trigger `chart_of_accounts_guard` added; 4 constraints, none added.
- **Focused tests:** 157, 10, 29, 89, 145 and 146: `Files=6, Tests=106`, PASS.
- **Full suite:** pgTAP Pass A `Files=157, Tests=2994`, PASS. HTTP: `verify_api_end_to_end` 35/0, `verify_journey_branches` 85/0, `verify_lifecycle_branches` 122/0. pgTAP Pass B without reset: 2994, PASS. Smoke: `ALL CHECKS PASSED (78 tables, … 71/623 catalog, …)`. 157 files whose literal `plan(N)` values sum to 2994.
- **Mutants M1–M9**, each proven installed by a changed function or privilege fingerprint, then restored with `md5(prosrc)` `6cafcfac…`, 4 constraints, no client EXECUTE, and 25/25. Baseline 25/25. Each failing set equals the Mutation Obligation table: M1 4,5,6,11,19,22,23; M2 5,19,22,23; M3 4,19,22,23; M4 none in pgTAP; M5 14,15; M6 14,15; M7 19,20; M8 19,23; M9 25.
- **Two-session race**, fresh tenant and entry per run, every session's own output read:
  - with the row lock: session A `BEGIN INSERT 0 1 INSERT 0 1 INSERT 0 1 COMMIT`; session B waited 3 s and was refused `chart account X: its code and type are fixed once a journal line is posted to it`; X stayed `revenue` with its 1 line;
  - with only the row lock removed (proven absent): A committed the same way; B did not wait, `UPDATE 1`; X became `expense` with the posted line under it. M4 is killed;
  - restored: the guard fingerprint above, and test 157 25/25.
- **Generators.**
  - `ai-map.json` and `repository-index.md` regenerate unchanged.
  - **One result differs from this contract's prediction.** Consumer Closure predicted `MASTER_API_CONTRACT.md` byte-identical. The generator changes one line: the table-door row for `chart_of_accounts` goes from insert guard `no`, update guard `no` to `yes`, `conditional`, because that section derives its guard columns from the table's triggers. The change is correct and derived; the file is in Write Scope, and Step 9 regenerates it. The regenerated file was set back until Step 9. **Lesson:** run every generator against the prototype before predicting a derived file byte-identical; a new trigger on a table moves this file.
- **Guard self-tests:**
  - `test_future_date_guard` 18/0 and `test_status_contradiction_guard` 33/0;
  - `test_cold_start_state_guard` 32/10, read in full from a second run. All ten failures are CONTROL or restore cases that require a CLEAN guard: CONTROL first, A2 CONTROL, A-restore, B-restore, C2 CONTROL, C-restore, D-restore, E-CONTROL, F-restore and CONTROL second direction. Every MUTATION case passes;
  - `test_primary_ledger_guard` 11/2: its two CONTROL cases; every MUTATION case passes.

  This is the drift Consumer Closure predicts, and Step 9 requires them green.
- **Scope and consistency.** `git status` shows only Write Scope paths, and `git diff --check` is clean. Repository consistency reports exactly the six predicted items, and Check 29 passes.
- **Fresh Primary baseline**, read-only through `supabase-primary`:
  - project URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`;
  - ledger 252 rows, `5f13c62d2f609e7794a0193a2f203c50`, latest `20261012120000`, with the target absent;
  - functions (Check L2/P2) `e6a65849bc390360dcb53b2be4f1a0b8`/331; `scripts/parity_surface.sql` (its query, comment lines omitted) `_combined` `02dcc5a1076506289a6f7ff81894fb4d`/3134, every surface equal to the recorded evidence and to the unrepaired local stack;
  - `chart_of_accounts`: triggers `chart_of_accounts_enforce_subscription_write_gate` and `chart_of_accounts_set_updated_at`, 4 constraints, no `app.guard_chart_account`;
  - 0 tenants, chart accounts, journal entries, journal lines and events; `catalog_values` 623.

  No drift from the approved baseline. **Predicted delta on Primary:** ledger 253, `b144bdf0f5a31ac66a0f0a723fb009bc`, with `20261013120000` once; functions `2cd20c3fea8247598eb9b2bbb559f2ca`/332; triggers 319; `_combined` `56625ae4118e1ddc85bab99114b17899`/3136; the guard and its trigger as above; no business row written.
- **Readiness verdict: PASS.** Step 7 finds no Gate 2 recorded, so execution stops here and the Gate-2 package goes to the owner.

### 2026-10-14 — Gate 2 recorded (Step 7)

- The owner first wrote "If you are satisfied with your work at that point, then I give you my approval." That conditional delegation was not taken as Gate 2, which requires the owner's own exact-byte authorization. The owner was asked the exact question and answered **"Authorize these exact bytes"** to: deploy exactly `supabase/migrations/20261013120000_a_used_ledger_account_keeps_its_meaning.sql`, SHA-256 `8b99747e6ab7afbc0ab7b600e7ada7413835252398bc8097a8b03b739205c0cc`, md5 `635d504d4069cafb52bd113112126a78`, 3858 bytes, to Primary `vrvtsxexkiiiivlkdxzp` only, valid only if the Step 8 recheck matches the recorded baseline exactly.
- It authorizes no other migration and no business-data write. Secondary `brplkqmbzffpxqgkkdzo` is never contacted.
- **Working-tree incident after Step 6, corrected before this gate.** To commit `97bd8b0` with only this contract, the uncommitted Steps 1–5 were backed up with their blobs and set aside with `git stash push --keep-index --include-untracked`; the unmodified hook ran and passed, and `git stash pop` restored them. Every blob matched, but `core.autocrlf=true` re-wrote the migration and test 157 as CRLF on disk (migration SHA-256 `7dcb6d47…`). The LF bytes were copied back from the backup and re-verified at their pinned SHA-256 values. **Lesson:** after any stash or checkout, verify the pinned SHA-256 of the bytes, not only the blob.

### 2026-10-14 — Primary deployment (Step 8)

- **Prewrite recheck**, immediately before the write, matched every Gate-2 condition exactly:
  - HEAD `97bd8b0`, 4 ahead of and 0 behind `origin/main` `4347817` after a fetch; the working tree held only Write Scope paths;
  - the migration file `8b99747e6ab7afbc0ab7b600e7ada7413835252398bc8097a8b03b739205c0cc`, md5 `635d504d4069cafb52bd113112126a78`, 3858 bytes, 68 LF, 0 CR; test 157 `e501187f4514f7ebb6843799ccb4229e477c1298640af0bac8b3e81a57982608`;
  - project URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`; ledger 252 `5f13c62d2f609e7794a0193a2f203c50`, latest `20261012120000`, target absent by version and by name;
  - functions (Check L2/P2) `e6a65849bc390360dcb53b2be4f1a0b8`/331; `chart_of_accounts` triggers `chart_of_accounts_enforce_subscription_write_gate` and `chart_of_accounts_set_updated_at`, 4 constraints, no `app.guard_chart_account`;
  - 0 tenants, chart accounts, journal entries, journal lines and events; `catalog_values` 623.
- **Write.** The transmitted text was proven server-side before the write by a read-only `select`: md5 `635d504d4069cafb52bd113112126a78`, 3858 bytes, 68 LF, 0 CR. It was applied once through `supabase-primary` as `a_used_ledger_account_keeps_its_meaning`. The connector assigned the temporary version `20261014071921`, whose single stored statement has the file's md5. One guarded UPDATE, in a block that raises unless exactly one row is renamed, renamed it to `20261013120000`; the guard required exactly one row after `20261012120000`, that statement md5, and no existing target.
- **Fresh post-deploy reads** (read at `2026-10-14T07:21:27Z`, Primary's clock):
  - ledger 253 `b144bdf0f5a31ac66a0f0a723fb009bc`, equal to the migration files, with `20261013120000` exactly once;
  - functions `2cd20c3fea8247598eb9b2bbb559f2ca`/332, triggers `9b53576506088625f67f8156f122bd44`/319, `_combined` `56625ae4118e1ddc85bab99114b17899`/3136. Policies, constraints, grants, columns, views, indexes, status transitions and RLS are unchanged. Every value equals the local stack after a clean reset (Step 6);
  - `chart_of_accounts` triggers now add `chart_of_accounts_guard`; 4 constraints, none added;
  - `app.guard_chart_account` `md5(prosrc)` `6cafcfacc4ef4648df5af67e5952dbdb`, SECURITY DEFINER, `search_path=""`, ACL `{postgres=X/postgres}`, executable by neither `authenticated` nor `anon`;
  - `catalog_values` 623; 0 tenants, chart accounts, journal entries, journal lines and events.

  No business row was written. Secondary was not contacted.

### 2026-10-14 — Post-deploy state (Step 9)

- `primary-ledger-evidence.json` was rewritten from the Step 8 readings only, read at `2026-10-14T07:21:27Z`. The 253-entry ledger is the previous 252 plus `20261013120000_a_used_ledger_account_keeps_its_meaning`, and that list hashes to Primary's own `b144bdf0f5a31ac66a0f0a723fb009bc`.
- The manifest's Live state is 253 migrations with the same fingerprints, verified 2026-10-14; the catalog (71/623) and the 464 HTTP assertions are unchanged.
- `supabase/tests` holds 157 files whose literal `plan(N)` values sum to 2994, so the suite is `157 files / 2994 assertions`.
- COA-1 and COA-2 are `DEPLOYED` with Cert `✅`, and their freshness entry reads "new and fixed" without a new date.
- **Generators.** `MASTER_API_CONTRACT.md` changes the one line Step 6 recorded (`chart_of_accounts`: insert guard `yes`, update guard `conditional`); `ai-map.json` and `repository-index.md` regenerate unchanged.
- **Guard self-tests, all green:** `test_future_date_guard` 18/0, `test_status_contradiction_guard` 33/0, `test_cold_start_state_guard` 42/0, `test_primary_ledger_guard` 13/0.
- **Checks:** `check_primary_ledger` `RECOVER-1 LEDGER EVIDENCE: CLEAN`; `check_database_parity_evidence` `PRIMARY PARITY EVIDENCE: CLEAN`; `REPOSITORY CONSISTENCY: CLEAN`; `git diff --check` clean. `git status` shows only Write Scope paths.
- **Runtime Checkpoint:** DONE.

### 2026-10-14 — Post-deploy local certification (Step 10), and a conflict that stops the Complete transition

- **Implement** committed as `2796097`; its pre-commit Gate reported `REPOSITORY: clean`, `BLOCKER: none`.
- **Local certification.** Canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` ran on the clean committed HEAD `2796097` under `scripts/run_timed.ps1`, with nothing else running (`concurrent=0`). It ran in VERIFY mode (`STEP: DONE`) and reported `LOCAL_CERTIFY: READY` in 2.9 min, exit 0. Every mandatory verification passed in that run: reset; pgTAP Pass A; the three HTTP suites; pgTAP Pass B; smoke; `check_database_parity_evidence.ps1`; repository consistency; `git diff --check`; `check_primary_ledger.ps1`.
- **Selector after SPEC-278** (`scripts/batch6_select_target.ps1` on the local stack after that reset; 35 surfaces still `NOT-RECORDED`), as Exposure/coverage:
  1. `notification_deliveries` 7/42
  2. `approval_requests` 7/52
  3. `user_branch_assignments` 7/590
  4. `departments` 7/654
  5. `user_role_assignments` 7/660
  6. `customer_consents` 6/18
  7. `document_retention_policies` 6/36
  8. `document_links` 6/54
  9. `exchange_rates` 6/66
  10. `user_permission_grants` 6/88
  11. `catalog_values` 6/102
  12. `events` 6/346

  Slice 43's measured target is `notification_deliveries` (Exposure 7, coverage 42).
- **The conflict.** Step 10 says the Complete commit sets `Next capability` to "Batch 6 Slice 43, naming the measured first target" and `Current Module` to "resuming at Slice 43", and the Acceptance Criterion reads "The manifest names Batch 6 Slice 43 and its measured target as the next capability, with no Active Change Request." Both copy SPEC-268's Complete commit. After SPEC-268, SPEC-270 fixed CTRL-12 by deleting exactly that copy: a hand-copied target is compared by nothing, and in its measurement a wrong one passed every guard. Since then the manifest names the selector, "never a copy of it here", and SPEC-273 to SPEC-277 kept that form. This contract's own range has not touched `Next capability` or `Current Module`.
- **Owner decision, 2026-10-14 (verbatim, in part):** "I choose to preserve the behavior established by SPEC-270. **Do not reintroduce CTRL-12 by copying the selected Batch 6 target or its ranking metrics into the manifest.** The manifest must continue pointing to the authoritative selector, `scripts/batch6_select_target.ps1`." The same decision states that it "is not blanket permission to bypass frozen contractual requirements", and that if no compliant path exists the executor must "stop before the Complete transition, report the precise blocker and the smallest governance-compliant recovery path. Do not mark an unsatisfied criterion as passed."
- **Determination (CR_LIFECYCLE §8):** the Acceptance Criterion's wording is frozen (`ACCEPTANCE_TEXT_MUTATED`), Step 10 is frozen (`FROZEN_AUTHORITY_MUTATED`), and `Complete` requires every Acceptance Criterion and Review Gate item ticked and a `Verdict: Confirmed Complete` (`COMPLETION_PREREQUISITE`). Under the owner's decision that criterion cannot be made true, and the Review Gate's "every change matches the Implementation Steps exactly" cannot be ticked for Step 10. **The Complete transition is therefore not made.** Nothing in the manifest was changed for it. The independent review and its verdict are in Verification Notes.

### 2026-10-14 — Cancelled by the owner (human command)

- **Authority.** The owner's decision of 2026-10-14 approves Outcome B: "I authorize the canonical cancellation of SPEC-278 and the preparation of one narrowly scoped successor Change Request." It is "a lawful recovery from an unsatisfiable frozen contract, not permission to bypass any repository protection". `In Progress → Cancelled` is a human-only transition (`CR_LIFECYCLE.md` §5); this commit records it.
- **Why.** The Review above found one Acceptance Criterion that cannot be made true without re-introducing CTRL-12, which the owner forbade, and no governance route to `Complete` that does not tick it (Verdict: Needs Corrective Change Request).
- **What stands, unchanged by this cancellation.** It is not a rollback.
  - **Engineering implementation applied:** migration `20261013120000_a_used_ledger_account_keeps_its_meaning.sql` (SHA-256 `8b99747e6ab7afbc0ab7b600e7ada7413835252398bc8097a8b03b739205c0cc`), test 157, test 10 at eleven, the `ENGINEERING_METHOD.md` bullet, and the register and disposition records, all committed in `2796097`.
  - **Primary deployment completed:** under the owner's exact-byte Gate 2 (Step 8); Primary's ledger, functions and structure equal local, and `reports/evidence/primary-ledger-evidence.json` records it.
  - **Local certification achieved:** `LOCAL_CERTIFY: READY` at `2796097` (Step 10).
  - **Contract completion blocked:** see the Review.
- **Nothing is reversed, renamed or re-applied.** No frozen section, criterion or checkbox changes, and no target is copied into the manifest. The manifest's Active Change Request becomes `None`, with `ai-map.json` regenerated by `scripts/generate-ai-map.ps1`.
- **What remains.** Closure and publication of this delivered work pass to one narrowly scoped successor contract. That contract names this file in its `Supersedes / Depends On` and carries these unpublished commits, under the segmented-publication rule (`CR_LIFECYCLE.md` §8, `SPEC-273`). It repeats no repair and deploys nothing. Its identity is allocated when it is drafted, and is not written here, because a tracked mention would reserve it.
- **Follow-ups, outside both contracts, each to its own authority:**
  - the blank-code reopening trigger's linkage, which needs a Live-deferred-items row in `reports/future-backlog.md`;
  - the four lessons recorded above, to be promoted into `ENGINEERING_METHOD.md`;
  - Batch 6 Slice 43, measured above.

## Verification Notes

### 2026-10-14 — Review (independent): Step 10 cannot be completed as frozen

**Independence.** The executor checked the implementation against the live state. A separate read-only reviewer, given no executor conclusions, then independently judged the Step 10 conflict and SPEC-270's preservation against the files and the Gate code.

**Acceptance Criteria, against the live state:**
- **Met:**
  - the COA-1 and COA-2 behaviour, by test 157 inside `-Finish`'s pgTAP run on the committed bytes;
  - the guard's mode, `search_path` and ACL, locally and on Primary, and no constraint or catalog enforcement added;
  - mutants M1–M9 and the causal negative (Step 6);
  - test 10 at eleven with `chart_of_accounts`;
  - the `ENGINEERING_METHOD.md` bullet;
  - COA-1 and COA-2 `DEPLOYED`, with STEPUP-1 the only other row changed;
  - `chart_of_accounts` `AUDITED` / `ADVERSARIAL` at 43 of 78, with no other disposition row changed;
  - the four files at their frozen values;
  - Primary, evidence, manifest Live state, API contract, `ai-map.json` and `repository-index.md` in agreement, with the guard self-tests and consistency CLEAN;
  - Primary received only the authorized migration and one guarded rename; Secondary was never contacted;
  - `git diff --name-only 4347817..HEAD` lies wholly inside Write Scope.
- **Not met, and not ticked:** "The manifest names Batch 6 Slice 43 and its measured target as the next capability, with no Active Change Request." The plain reading requires the target's name in the manifest; Business Reason confirms it ("It is the target the manifest names."). Reading it as naming the selector command is strained and is rejected.

**Review Gate.** "Every change matches the Implementation Steps exactly" cannot be ticked for Step 10.

**SPEC-270 preserved.** `git diff 4347817..HEAD -- _ORVION_CANONICAL/manifest.md` changes only `Live state` and `Active Change Request`. `Current Module` and `Next capability` still read "the first row of `scripts/batch6_select_target.ps1` (local stack), never a copy of it here"; no target or metric is copied.

**Legitimacy of each route to `Complete`, judged against CR_LIFECYCLE and the Gate:**
- **Already Applied** (`changes/TEMPLATE.md`): not legal. It applies only when a step's check finds the edit present, and the target copy was never applied.
- **Engineering Observation** (§11): can be recorded, but it needs a new judgment, so it becomes a future CR and never ticks a criterion.
- **Human completion** (§5): blocked the same way. `COMPLETION_PREREQUISITE` binds whoever completes.
- **A corrective CR while this one is In Progress:** not legal. At most one contract may be Approved or In Progress (§8, `ORPHANED_APPROVED_CR`).
- **Completing with the target copied and removing it later:** Gate-legal, but contrary to the owner's decision.
- **Cancel this contract (human only) and complete a successor that names it in `Supersedes / Depends On`:** legal (§8, SPEC-273; the SPEC-271 → SPEC-272 precedent). This is the only route that satisfies every constraint.

**Verdict: Needs Corrective Change Request.** Status stays `In Progress`. `Complete` is not attempted, because the Gate would correctly refuse it.

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

**Prototype environment (2026-10-13).** The owner authorized repeated local-only database resets for Batch 6 on the same day, on conditions that were each verified before the first reset:
- the target is the local `supabase_db_ORVION` on port 54322, and the CLI is not linked to any remote;
- every row in it was regenerable fixture data from the HTTP suites;
- a full `pg_dump` was taken (2.9 MB, 4051 TOC entries readable).

The candidate files were applied from a disposable clone with its push URL set to `none`, using the main checkout's pinned CLI 2.120.0 through `--workdir`. A first attempt used a `git worktree`, which `ENGINEERING_METHOD.md` §2 forbids for a sandbox. It made no commits and was removed.

**Two-session race (pre-approval, on the prototype stack).** Both sessions are session-less, so the integrity rule applies to them. Each run uses a fresh tenant, restores the prototype guard from source first, and prints session A's own output. Session A posts a header and two balanced lines, one to account X, and sleeps 4 s before committing. Session B retypes X.
- With the row lock: A committed; B waited 3 s and was refused 23514; X stayed `revenue` with 1 line.
- With only the row lock removed: A committed; B did not wait; X became `expense` with the posted line under it.

**Revision after the owner's Draft-level review (2026-10-13).** The owner asked which consumers read `name`, `parent_account_id` and `is_active`. The answer is in Business Reason. The same read found that the first Draft's COA-2 conflicted with ADR-0006:
- it added a hard-coded `CHECK (account_type in (...))`, which is neither of the two per-column techniques ADR-0006 and canon 30 name, on a column `202607051300` excluded by name, the backlog closed as NOT A GAP, and no consumer reads;
- it also added blank-text and parent-cycle rules with no measured consequence that warranted them.

A second review asked whether a blank code, which the posting RPC does consume, can be posted to. The measurement and its bounded consequence are in Business Reason. They correct this contract's earlier statement that no blank text has a consumer, and they add no constraint.

That repair is removed, its observations are recorded as positions with a reopening trigger, and the step-up finding is renumbered COA-2. Every hash, count and proof in this contract was re-measured on the revised bytes.

**What went wrong first, disclosed.**
- The first race posted nothing. A bare journal header is refused at COMMIT by the deferred balance check, so the fixture's own header never existed, and its "B did not wait" line was no evidence at all.
- A first injected rerun replayed stale rows, because journal rows cannot be deleted.

Both were caught by reading session A's output and the final state, and the harness was fixed. They are the lesson Step 4 promotes into `ENGINEERING_METHOD.md`.
