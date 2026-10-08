# Change Request — SPEC-246

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Foundation Completion Programme Batch 6 Slice 33: give `public.journal_entries` a truthful disposition and close **JE-5**.

JE-5 is the signed-in direct UPDATE door on `public.journal_entries`. Through it a CREATE_JOURNAL_ENTRY holder, at aal1 as well as aal2, rewrote a posted entry's header with no new event: its entry date, description, source type, source entity, creation timestamp and void metadata.

After this change the invariant is: **a signed-in caller may read journal-entry headers according to tenant scope, but may neither create nor mutate a posted journal entry through the table door.** Creation belongs to the governed `app.create_journal_entry` operation, and correcting a posted entry is represented by a new financial record (a reversal), never by mutating historical truth.

The same revoke also removes the `authenticated` INSERT grant on the header. That is a bounded least-privilege cleanup coupled to the same door closure, not a second JE-5 exploit (see Business Reason).

Record **JE-6**, the RPC's unvalidated `source_entity_id`, as OPEN and do not repair it. Record the surface `AUDITED-OPEN`, and set the next capability to the Slice-34 target the selector then measures.

This contract does not eliminate platform maintenance paths (`postgres`, `service_role`); FIN-9 stays separately owned. It does not touch JE-2, DC-11, n8n or any Phase-8 work, and it builds no reversal or void workflow.

## Business Reason

### Selection
`scripts/batch6_select_target.ps1` at `7e6f51e` ranks `journal_entries` first: `NOT-RECORDED`, Exposure 10, coverage 52, 10 test files, 2 direct writes, 1 SECURITY DEFINER function and 1 RPC. The runner-up is `tenant_license_activations` at 8/30.

### Authority
- **Canon 07:** "Any correction after approval must be handled through a new event, adjustment, reversal, or authorized finance action."
- **Canon 30, Financial Record Standard:** corrections use an adjustment, a reversal, a new journal entry or an event; "Do not overwrite approved financial actions silently"; avoid physical delete.
- **The register's `journal_entries` closure (VOID-1):** a POSTED double-entry record is corrected by a compensating reversal, never by mutation, and `voided_at`, `voided_by` and `void_reason` "must never be given a writer". The column comment on `voided_at` says the same.
- **No draft state.** `app.create_journal_entry` writes the header and every line in one call and records `journal_entry_created` with the source type as `new_state`, the description as `reason`, and `total_amount` and `line_count` in its payload. No function updates a header, and `app.status_transitions` has no `journal_entries` row.

### Field classification
- **System-maintained:** `id` and `tenant_id` (the primary key, the composite foreign key from the lines, and RLS); `created_by` (`app.derive_created_by` pins it on UPDATE); `created_at` (defaults to `now()`, but nothing pinned it).
- **Immutable after posting:** `entry_date`, `description`, `source_type_code`, `source_entity_id`. The RPC sets them once, and no authority defines an operation that edits them.
- **Never written (VOID-1):** `is_voided`, `voided_at`, `voided_by`, `void_reason`.

No header field is legitimately editable by a signed-in user, and no field's authority is unclear. ORVION defines no draft, void, cancellation, deletion or reversal-link operation for journal entries. A correction is a new compensating entry posted through the same RPC, which canon permits; the absence of a dedicated reversal operation is an observation, not a defect, and does not license mutation.

### JE-5 (Medium) — the reproduced defect
`authenticated` holds UPDATE on `journal_entries` under `scope_update`, which charges `app.has_permission('CREATE_JOURNAL_ENTRY')` and no step-up. Measured at `7e6f51e` on the local stack, rolled back, as a `finance_manager` whose posted entry `2026-10-01 | Posted E1 | manual_entry` carried one event agreeing with it. Each of these landed, at aal2 and at aal1 alike:
- **Backdated or post-dated:** `entry_date` set to `2001-01-01`, or to the last day of the year 2099;
- **Re-described:** `description` replaced;
- **Re-sourced:** `source_type_code` set to `refund`; `source_entity_id` set to another tenant's invoice, or to a nonexistent id;
- **Voided:** `is_voided`, `voided_at` and `void_reason` set, once with `voided_by` empty and once naming an employee of the same tenant;
- **Re-timed:** `created_at` set to 2001.

In every case the lines and the one `journal_entry_created` event were unchanged and no event recorded the change, so the event then contradicted the header's source and narrative. The entry's date and creation time moved with no trace at all.

Over PostgREST, one request each: an aal1 PATCH setting date, description and void columns (with an employee as `voided_by`) returned **200**, and a second aal1 PATCH rewriting `created_at` and the source returned **200**. The same session's `rpc/create_journal_entry` returned **403** (`multi-factor authentication required for this role`). The header ended `2001-01-01 | rewritten at aal1 | refund | <dangling id> | created 2001 | voided by the employee`, with lines `2500/2500 EGP` and one event still saying `manual_entry | Posted over HTTP | 2500`.

Held, not defects: `created_by` was silently pinned; a `tenant_id` change was refused by RLS; an `id` change was refused by the lines' foreign key; a `voided_by` naming another tenant's user was refused by the composite foreign key; an employee, a rival tenant's finance manager, an inactive finance user and one with an explicit CREATE_JOURNAL_ENTRY deny each updated 0 rows; DELETE has no grant (42501, HTTP 403).

**Severity context, not inflation:** since SPEC-245 closed the line door, the header is the only signed-in path that alters a posted ledger record. Exposure: Primary holds 0 journal entries.

### The INSERT grant — least-privilege residue, not a second JE-5 exploit
`authenticated` also holds INSERT on the header under `scope_insert`, again permission without step-up. In this investigation it produced **no** committed harmful entry: a header-only INSERT is accepted at the statement and then refused at COMMIT by FIN-8's deferred check (`journal entry … has 0 line(s)`), at aal2 and aal1 alike, and over HTTP as a 400. Since SPEC-245 no signed-in user can write the lines that would let it commit.

Its removal is earned for a different reason:
- no legitimate signed-in workflow needs a direct table INSERT;
- `app.create_journal_entry` is the creation path, and it charges permission and step-up;
- the direct INSERT bypasses that authority and depends on an integrity constraint to stop it completing;
- the grant alone keeps `journal_entries` inside STEPUP-1's direct-write criterion.

### JE-6 (Low) — recorded OPEN, not repaired
`app.create_journal_entry` stores any `p_source_entity_id`: a nonexistent id, another tenant's invoice id, or an id on a `manual_entry`. Measured at `7e6f51e`, rolled back: all three committed through the RPC at aal2. There is no foreign key on `source_entity_id`, which is polymorphic over `journal_entry_source_type`.

The current severity is Low:
- no disclosure was demonstrated (the RPC stores the id and reads nothing behind it);
- no function, view or report reads the column.

Repair needs authority the canon does not give: which table each source type points to, and whether a manual entry may carry a source. This contract does not invent that model.

### The repair
```sql
revoke insert, update on public.journal_entries from authenticated;
```
`app.create_journal_entry` has run SECURITY DEFINER since SPEC-245 and needs neither grant, so it becomes the header's one signed-in writer, as it already is of its lines. SELECT stays; DELETE was never granted. Nothing else changes:
- no trigger, function, state machine, RLS mechanism or column grant;
- the now-dead `scope_insert` and `scope_update` policies stay, as the dead `scope_delete` already does and as SPEC-245 left the line policies;
- no accounting-model change.

### Rejected
- **Revoking UPDATE alone:** it closes JE-5 but leaves the INSERT residue above, and keeps the table in STEPUP-1.
- **An immutable-header trigger:** no signed-in writer would remain to stop, and the platform is FIN-9's question.
- **Column grants for "editable" fields:** no field is legitimately editable.
- **Pinning `created_at` with a trigger:** no signed-in door reaches it after the revoke.
- **A void or reversal operation:** VOID-1 closes voiding, and canon defines no reversal workflow.
- **Repairing JE-6:** see above.

### Held, recorded so a later slice does not rediscover it
- **FIN-8:** set rules unchanged; the header INSERT is now refused by authority before they are reached.
- **FIN-9:** unchanged; the platform remains able to write a header and lines without an event.
- **JE-2 and DC-11:** unchanged and OPEN; no dependency.
- **Tenant isolation:** RLS read scope and composite foreign keys held.
- **Concurrency:** none applies. After the repair no signed-in operation changes a header, so there is no header invariant two sessions could race; the line balance race is JE-4's, closed by SPEC-245.

## Risks

- **A legitimate writer losing its door.** None exists. The RPC is the only signed-in writer and runs as definer. No application, script or function writes a header directly; the only direct writers were tests.
  - Test 89's JE-1 fixture inserted its header as `authenticated`; it now does so as the platform, beside the JE-1 line writes it already made as the platform. Its purpose is unchanged, still `plan(21)`.
  - Test 83's assertion 23 (actor columns on a table `authenticated` can write directly) loses `journal_entries.voided_by`, because the table is no longer directly writable. That departure is the guard working; assertion 22, which asks no grant question, keeps it.
- **A refusal that moves.** Tests 29 and 70 assert an employee's header INSERT is refused with 42501. The refusal now comes from the missing grant instead of RLS, with the same SQLSTATE, and both pass unchanged. The HTTP table POST becomes a 403 instead of a 400, and its check is pinned to 42501, because "not 2xx" was already true before the repair and cannot detect a restored grant.
- **Primary deployment** revokes two table privileges and nothing else. Primary holds 0 journal entries. It requires separate exact-byte owner authorization (Gate 2); approving this contract does not authorize it.
- **Workstation, not in scope:** a `supabase db reset` run from a scratch git worktree leaves local storage at 74 migrations without the `bucketid_objname` index, so storage uploads fail `42P10` and the storage HTTP suite and Pass B's retention tests go red. A clean worktree at `7e6f51e` with no changes fails identically, so it is not this repair. Resets for this contract run from the main checkout.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-246-a-posted-journal-entry-is-never-rewritten.md`
- `supabase/migrations/20261008150000_a_posted_journal_entry_is_never_rewritten.sql`
- `supabase/tests/146_a_posted_journal_entry_is_never_rewritten_test.sql`
- `supabase/tests/83_actor_attribution_test.sql`
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
- `supabase/migrations/20261008120000_a_journal_line_is_written_only_with_its_entry.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/29_financial_write_authority_test.sql`
- `supabase/tests/53_api_surface_test.sql`
- `supabase/tests/70_journal_entry_balance_test.sql`
- `supabase/tests/72_invoice_allocation_ceiling_test.sql`
- `supabase/tests/73_quotation_total_derivation_test.sql`
- `supabase/tests/102_financial_account_identity_and_definer_surface_test.sql`
- `supabase/tests/106_otp_challenge_subject_authority_test.sql`
- `supabase/tests/145_a_journal_line_is_written_only_with_its_entry_test.sql`
- `reports/architecture-decision-records.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/07_finance_model.md`
- `_ORVION_CANONICAL/30_database_conventions.md`
- `_ORVION_CANONICAL/31_schema_draft.md`
- `scripts/verify_database.sql`
- `scripts/verify_api_end_to_end.ps1`
- `scripts/verify_care_journeys.ps1`
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
- `_ORVION_CANONICAL/07_finance_model.md` (corrections after approval); `_ORVION_CANONICAL/30_database_conventions.md` (Financial Record Standard); `_ORVION_CANONICAL/31_schema_draft.md` (`journal_entries`); `_ORVION_CANONICAL/28_permissions_matrix.md` (CREATE_JOURNAL_ENTRY)
- `reports/master/MASTER_GAP_REGISTER.md` (FIN-8, FIN-9, JE-1 to JE-5, DC-11, STEPUP-1, ATTR-2, VOID-1 and the `journal_entries` CLOSED BY DESIGN block)
- `reports/master/MASTER_EXECUTION_PLAN.md` Batch 6 method and EC-1…EC-11; `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `changes/SPEC-245-a-journal-line-is-written-only-with-its-entry.md`
- Current local `app.create_journal_entry`, `app.derive_created_by`, `app.enforce_journal_entry_balanced`, `app.authorize`
- Tests 29, 70, 83, 89, 145

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
| `authenticated` loses INSERT and UPDATE on `journal_entries` | Tests 29, 70 (employee header INSERT), 83 (assertion 23), 89 (JE-1 fixture), 10, 106; PostgREST's table door; `verify_journey_branches.ps1` | WRITE | The prototype was a scratch worktree at `7e6f51e`; the migration was applied with its ledger row on a stack reset from the main checkout. Migration SHA-256 `4b8a88cd41c9d9355bdf7dd3f1fa89e31f91bdff2a9da52ecedb48982f73fcbc`. Tests 29 and 70 pass unchanged (42501 now from the grant). Test 89 writes its fixture header as the platform (LF SHA-256 `c4e12233fe4344033e604013a4da3ce59a5aaf07d384e367901b05ffbaa65cf4`, 21/21). Test 83's assertion 23 drops `journal_entries.voided_by` (working-tree CRLF SHA-256 `868ecc18194cd7e7e12add2f60eb336cee342a2b411ddc08e789892ce568bc62`, LF normalization `fb17908638b632a5214b4c50b8e7845720e14011850a57e956d9c962ea5e9ef7`, 23/23). Tests 10 and 106 pass unchanged; 106 counts policies, which stay. `verify_journey_branches.ps1` pins the table POST to 42501 and gains four JE-5 checks (LF SHA-256 `b459a7ce0b6fc8def2928fba6019fcddd3533a1e8ee872d13a31b1dbfa36714c`, 83/0). With INSERT and UPDATE restored, exactly those five checks fail (POST 400 from the deferred check; three PATCHes 204; the header rewritten) and the other 78 pass. |
| `app.create_journal_entry`, the header's one signed-in writer | Tests 70, 89, 145, 146; `verify_journey_branches.ps1`'s ledger block | VERIFY | Unchanged bytes. It still posts at aal2, and still refuses aal1 (403 over HTTP), an employee and an unbalanced entry. |
| The table's generated API row | `MASTER_API_CONTRACT.md` | WRITE | The canonical generator against the prototype grants reports 80 RPC endpoints (80 with HTTP evidence), 8 views and 74 tables. Exactly one line moves, `journal_entries` `SIU-` → `S---` (prototype SHA-256 `d28fb5672ca9c0795a99a74746069c973e1392edcc5e3d2a5a315348138175fd`). |
| Suite, HTTP and smoke | full pgTAP; the six HTTP suites; `scripts/verify_database.sql` | VERIFY | On the prototype, in `-Finish`'s order on a main-checkout reset: Test 146 17/17; pgTAP Pass A 146 files / 2674 assertions PASS (2657 + 17); HTTP 35 + 40 + 83 + 122 + 122 + 60 = 462 passed, 0 failed; Pass B 146 / 2674 PASS; smoke `ALL CHECKS PASSED (78 tables, … 71/622 catalog, …)`; `git diff --check` clean. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | Measured in a rolled-back transaction on the local baseline (equal to Primary, `f18fcf70…`/3110): grants `b6791b01807286f0d66baa3239b5869a`/191 → `6727f6d89168b7aec4c06f131bef75bc`/189; combined → `f50dea30bd2a7c4cf4c22ddd9e191622`/3108; functions, triggers, policies and every other surface unchanged. The 243-file ledger fingerprint is `201d938a80ae5fe6d32fb8ef6f3a7619`. |
| Measured state that moves | manifest (`Live state`, suite and HTTP figures, coverage, Last Completed, Current Module, Next capability); `primary-ledger-evidence.json`; `ai-map.json` | WRITE | 242 → 243 migrations, latest `20261008150000`; 145 → 146 files, 2657 → 2674 assertions; HTTP 458 → 462; coverage 33 → 34 of 78. Tables (78), catalog (71/622) and client RPCs (80) do not move. Primary values are written only from fresh post-deploy readings. |
| JE-5 fixed, JE-6 recorded, STEPUP-1 annotated; the surface `AUDITED-OPEN` | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24 | WRITE | Test 146's `-- ATTACK-CLASSES:` line and negative assertions satisfy Check 24 for `journal_entries`. The disposition row names this contract as its session. |
| CI-only guard self-tests and repository consistency | `scripts/test_*_guard.ps1` (four); `scripts/check_repository_consistency.ps1` | VERIFY | On the prototype, future-date (18/0) and status-contradiction (33/0) pass. Primary-ledger (11 passed, 2 failed) and cold-start (25 passed, 9 failed) fail ONLY their CONTROL cases that require an untouched copy of the repository to be CLEAN; every mutation case passes. Repository consistency reports exactly the pre-deploy measured-state drift: `manifest says 242 migrations, repository holds 243`; latest `20261008120000` vs `20261008150000`; ledger fingerprint `5f8565a1…` vs `201d938a…`; `145 test files` vs 146; `2657 assertions` vs 2674; RECOVER-1 ledger evidence. These are not waived: Step 7 makes them true and Step 8 requires them green. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused tests, pgTAP A/B, the six HTTP suites, smoke and mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| JE-5, JE-6 and the disposition describe the local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |
| The four CI-only guard self-tests pass | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `202607056100`'s grant rule (a write grant is kept exactly where a sanctioned writer needs it), applied as SPEC-244 applied it to the merge and SPEC-245 to the journal lines. The writer it keeps is the existing definer RPC. Nothing new is added: no trigger, function, permission, event type, policy or column grant. Rejected: revoking UPDATE alone; an immutable-header trigger; column grants; a void or reversal operation.

Added Property: No signed-in user, at any step-up level, can create a journal-entry header or change any field of a posted one through the table door. Creation is only through `app.create_journal_entry`, which charges permission and step-up, and every posted header still says what its `journal_entry_created` event says.

Causal Negative: The pre-repair measurements in Business Reason, at `7e6f51e`:
- backdating, re-description, re-sourcing, voiding (with a forged voider) and re-timing at the table, at aal2 and aal1;
- the same over HTTP at aal1 (two PATCHes, 200 each, against the RPC's 403);
- Test 146 on the unrepaired schema: assertions 1, 4–9, 11–13, 15 and 16 fail, each for its intended reason (no exception where 42501 was required, or the header changed).

Positive Test Design: One tenant: a `finance_manager` posts an entry through the RPC at aal2, and an `employee` holds no ledger permission. A second tenant's `finance_manager` looks across the boundary. The finance manager's permission and step-up are asserted as premises at aal2, and permission without step-up at aal1, so every refusal is the missing door.

Negative Test Design:
- **The door:** `authenticated` holds SELECT and no table or column INSERT or UPDATE, and no DELETE (column-aware, because a column grant reaches a column with no table grant).
- **JE-5 at aal2:** each of backdating, re-description, re-sourcing, voiding with an employee as voider, and re-timing `created_at` is refused 42501 `permission denied for table journal_entries`.
- **INSERT:** a bare header is refused 42501 at the statement, not left to the balance check at COMMIT.
- **aal1:** the same caller is refused rewriting the header and inserting one.
- **Employee and tenant:** the employee is refused at the door; the rival tenant reads none of the ledger and has no door to write it.
- **Records:** the header and its lines are byte-for-byte what the RPC wrote, and the one event still agrees with the header (posting, source, narrative, total, actor).
- Every refusal is asserted at the statement; nothing runs `set constraints … immediate`, so no deferred balance check queued by the RPC can refuse in a rule's place.

Non-Empty Population Obligation: Two tenants with active enterprise subscriptions. Tenant one has a `finance_manager` and an `employee`, a seeded chart of accounts and one posted entry with its event; tenant two has its `finance_manager`.

Mutation Obligation: Out of file, record a surface of `public.journal_entries`' table ACL and the count of its column ACLs. For each mutant:
1. Install it and prove the surface differs.
2. Run Test 146 and record the failing assertions.
3. Restore it and prove the surface equals the base.

A mutant whose installation is not proven is a harness error, never a kill.

| Mutant | Change | Expected to fail |
| --- | --- | --- |
| M1 | table UPDATE restored | 1, 4, 5, 6, 7, 8, 11 |
| M2 | table INSERT restored | 1, 9, 12 |
| M3 | column UPDATE (`entry_date`) | 1, 4 |
| M4 | column UPDATE (the four void columns) | 1, 7 |
| M5 | column UPDATE (`created_at`) | 1, 8 |
| M6 | column UPDATE (`description`) | 1, 5 |
| M7 | column UPDATE (`source_type_code`, `source_entity_id`) | 1, 6 |
| M8 | column INSERT (the header columns) | 1, 9, 12 |
| H1 | table INSERT and UPDATE restored, over HTTP | `verify_journey_branches.ps1`'s pinned POST check, its three JE-5 PATCH checks and its header NON-MUTATION check |

Prototype result: base surface `{postgres=arwdDxtm/postgres,service_role=Dxtm/postgres,authenticated=r/postgres} cols=0`. Every installation changed the surface and every restoration returned it to the base. All eight were killed:

| Mutant | Failing assertions |
| --- | --- |
| M1 | 1, 4, 5, 6, 7, 8, 11, 13, 15, 16 |
| M2 | 1, 9, 12 |
| M3 | 1, 4, 16 |
| M4 | 1, 7, 16 |
| M5 | 1, 8, 16 |
| M6 | 1, 5, 13, 15, 16 |
| M7 | 1, 6, 16 |
| M8 | 1, 9, 12 |

H1 failed exactly the five named checks and passed the other 78.

Post-Implementation Proof Obligation: All of the following, on the final bytes and through canonical `-Finish`:
- the focused tests, a clean reset from the main checkout, pgTAP Pass A, the declared HTTP suite, pgTAP Pass B and smoke;
- the out-of-file mutations M1–M8, H1 and the pre-repair causal negative;
- the generated artifacts, the four CI-only guard self-tests, repository consistency and `git diff --check`;
- fresh Primary evidence, parity evidence and the Primary ledger check.

## Implementation Steps

1. **Check** that `supabase/migrations/20261008150000_a_posted_journal_entry_is_never_rewritten.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `4b8a88cd41c9d9355bdf7dd3f1fa89e31f91bdff2a9da52ecedb48982f73fcbc`, md5 `fbd6f81ad12d64bf8d4af2d3fa3b650a`, 2177 bytes.
   - Its one statement is `revoke insert, update on public.journal_entries from authenticated;`, preceded by a comment block stating the authority, JE-5's measurements and why the INSERT grant goes too.
   - If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/146_a_posted_journal_entry_is_never_rewritten_test.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `f2074d7443596f8404d3de85018671d22f9763c7a52dca03e68bd1f8c332cfab`, `select plan(17);`.
   - Its `-- ATTACK-CLASSES:` line reads `DOOR BUSINESS STATE PRIVILEGE AUTH TENANT OBSERVABILITY INPUT=N/A REPLAY=N/A CONCURRENCY=N/A`, with each `N/A` reason in its header.
   - Then make three edits, each byte-identical to the prototype:
     - `supabase/tests/83_actor_attribution_test.sql`, kept CRLF in the working tree as it already is: assertion 23's pinned set drops `journal_entries.voided_by`, its message records the departure, and its family comment says why; working-tree SHA-256 `868ecc18194cd7e7e12add2f60eb336cee342a2b411ddc08e789892ce568bc62` (LF normalization `fb17908638b632a5214b4c50b8e7845720e14011850a57e956d9c962ea5e9ef7`), still `plan(23)`.
     - `supabase/tests/89_finance_periphery_parent_state_test.sql`, LF: the JE-1 fixture header is inserted after the existing `reset role`, as the platform, with a comment saying why; SHA-256 `c4e12233fe4344033e604013a4da3ce59a5aaf07d384e367901b05ffbaa65cf4`, still `plan(21)`.
     - `scripts/verify_journey_branches.ps1`, LF: the FIN-8 table-POST check pinned to 403/42501, and four JE-5 checks after the JE-3 block; SHA-256 `b459a7ce0b6fc8def2928fba6019fcddd3533a1e8ee872d13a31b1dbfa36714c`.
   - If a target carries content other than its `7e6f51e` bytes or its frozen value, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` already contains a `JE-6` row. If not, make these edits and nothing else:
   - **Register:**
     - a 2026-10-08 Slice-33 freshness entry, with the previous one demoted to `Previously:`;
     - JE-5 becomes FIXED by SPEC-246 locally with Primary pending and Cert `🛡`, its text recording the widened measurement (`created_at`, the forged `voided_by`, source re-pointing), the HTTP proof and the INSERT grant's separate least-privilege reason;
     - a new row JE-6 (Low, OPEN), with the evidence and the unresolved authority above, and its trigger being a decision on the source-type-to-entity mapping and manual-entry semantics;
     - one dated sentence on STEPUP-1: `journal_entries` no longer meets the criterion, because `authenticated` holds no INSERT or UPDATE on it.
   - **Disposition:**
     - a freshness entry, with the previous one demoted;
     - coverage 34 of 78 (18 `AUDITED-OPEN`, 44 `NOT-RECORDED`) and the "All 34" line;
     - the `journal_entries` row `AUDITED-OPEN` / `ADVERSARIAL` / SPEC-246 / JE-5, JE-6, with its evidence and its swept non-defects.

   If a target carries content other than its `7e6f51e` bytes, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 values:
   - a clean local reset from the main checkout; Test 146 and the focused Tests 83 and 89;
   - pgTAP Pass A, all six HTTP suites, then pgTAP Pass B without reset; smoke and the plan sum;
   - the mutation evidence M1–M8 and H1, and the causal negative;
   - the API-contract and map generators;
   - the scope check, `git diff --check` and repository consistency.

   Treat as expected at this boundary only: an undeployed Primary, the pre-deploy repository-consistency drift listed in Consumer Closure, and the guard self-test CONTROL failures it causes.

   Read a fresh Primary baseline, read-only:
   - the project URL, the full ordered ledger and the absence of the target migration;
   - the function and structural surfaces;
   - `journal_entries`' ACL and column ACLs; `app.create_journal_entry`'s definition md5 and security mode;
   - the tenant, journal-entry, journal-line and event counts.

   Record the predicted delta.
5. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 4 and present the Gate-2 package. Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261008150000_a_posted_journal_entry_is_never_rewritten`. If it is absent and deployment is separately authorized:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts and the table ACL.
   - On an exact match, prove the transmitted text's md5 server-side, then apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row, its stored statement md5 equal to the file's, and no existing target version.
   - Read fresh: the ledger, the function surface and all ten structural surfaces; `journal_entries`' ACL and column ACLs; the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with 462 HTTP assertions last passed on the Step-4 date.
   - Confirm that `supabase/tests` holds 146 files whose literal `plan(N)` values sum to 2674, then set `Suite **146 files / 2674 assertions**`; if either differs, stop.
   - Set Batch 6 coverage to 34 of 78, all thirty-four at `ADVERSARIAL`.
   - Mark JE-5 `DEPLOYED` with Cert `✅`, worded without a date beneath the register's freshness line.
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
     - set `Last Completed` to SPEC-246 / Slice 33;
     - set `Current Module` to Foundation Completion Programme Batch 6 resuming at Slice 34;
     - set `Next capability` to **Foundation Completion Programme — Batch 6 Slice 34**, naming the measured first target, followed by the Phase-8 order roadmap 32 owns, keeping its closed-chapter and standing-fact sentences;
     - keep the manifest within 7000 characters;
     - regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate with `scripts/publish_candidate.ps1` and require exact-SHA candidate CI.
   - Promote the same accepted SHA, require main CI, and run `-Certify` for `REMOTE_CERTIFY: READY`.
   - Verify synchronized clean refs.

## Acceptance Criteria

- [ ] `authenticated` holds SELECT and no table or column INSERT, UPDATE or DELETE on `journal_entries`. Its direct UPDATE and direct INSERT are refused with 42501 at the statement, in pgTAP and over HTTP.
- [ ] SELECT remains available within tenant scope: the finance manager reads its own entry, and a rival tenant's finance manager reads none.
- [ ] A posted header cannot be backdated, post-dated, re-described, re-sourced or re-timed, and its void columns cannot be written, by a CREATE_JOURNAL_ENTRY holder at aal2 or aal1, through the table door.
- [ ] `app.create_journal_entry` still posts for an authorized aal2 caller, and still refuses an employee (permission), an aal1 caller (step-up) and an unbalanced entry. Its bytes are unchanged.
- [ ] Every posted header and its lines are what the RPC wrote, and its one `journal_entry_created` event still agrees with it; no signed-in table write can make them diverge.
- [ ] No refusal is supplied by an unrelated deferred check: Test 146 asserts each at the statement, and the INSERT refusal is 42501, not 23514.
- [ ] Mutants M1–M8 are each killed against Test 146, and H1 against `verify_journey_branches.ps1`'s five named checks, with installation and restoration proven. The causal negative is recorded.
- [ ] JE-5 is fixed and deployed in the register. JE-6 is recorded OPEN, Low, and unrepaired: `app.create_journal_entry` and its `source_entity_id` handling are unchanged. STEPUP-1 carries its dated sentence. JE-2, DC-11 and FIN-9 are unchanged.
- [ ] `journal_entries` is `AUDITED-OPEN` / `ADVERSARIAL` in the disposition record, and coverage is 34 of 78. No other surface's row changed.
- [ ] The migration, Test 146 and the edits to Tests 83 and 89 and the HTTP script matched their frozen SHA-256 values when applied.
- [ ] Primary, the recorded evidence, the manifest (243 migrations; 146 files / 2674 assertions; 462 HTTP assertions), the API contract and `ai-map.json` agree, and the four CI-only guard self-tests and repository consistency pass.
- [ ] The manifest names Batch 6 Slice 34 and its measured target as the next capability, with no Active Change Request.
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

## Notes

- **EARN IT.** JE-5 was reproduced on the pre-repair schema in a rolled-back transaction, over HTTP at aal1, and by Test 146 failing for its intended reasons. The INSERT grant is removed on least privilege and STEPUP-1 membership, not on a reproduced exploit.
- **WORTH IT.** A posted entry's period, source, narrative, creation time and void status could be rewritten without step-up and without a trace, while its event still described the original.
- **SIMPLIFY IT WITHOUT WEAKENING.** Two grants are removed and nothing is added. The existing definer RPC stays the one signed-in writer of an entry, as it already is of its lines.
- **Owner authorization (2026-10-08).** The owner authorized creating this Draft only. That is not Approval, Begin, a Primary write, Gate 2, publication or Slice 34.
- **Deliberately not changed:** JE-2 and DC-11; JE-6 and `app.create_journal_entry`; FIN-9 and the platform paths; the dead `scope_insert`, `scope_update` and `scope_delete` policies; canon 07, 30 and 31; the n8n workflow and Phase 8; the workstation's scratch-worktree reset issue; the registered worktrees `owt/p2` and `C:\w234`.
