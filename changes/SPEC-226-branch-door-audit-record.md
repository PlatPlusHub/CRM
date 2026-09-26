# Change Request — SPEC-226

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Record Batch 6 Slice 24's audit of `branches`: a permanent adversarial test that pins what holds and what does not, two reproduced findings, one structurally discovered class of candidates, the surface's disposition, and every manifest figure that recording moves, with no schema change.

## Business Reason

Batch 6 Slice 24 selected `branches` live at Exposure 10, coverage 584; `subscriptions` was runner-up at 10/604. Both passes were run in rolled-back local transactions.

- **BRANCH-1 (Low, reproduced).** An `owner` holding MANAGE_BRANCHES at `aal1` was refused `multi-factor authentication required for this role` by `app.create_branch` and by the child `branch_business_hours` guard, then created a branch and set the tenant's Main branch to a new name, a new slug and `is_active = false` through the table. The RPC charges `app.authorize` (permission and step-up); the table's policies charge `app.has_permission` (permission only) and no trigger on `branches` charges step-up. It is Low because nothing reads any branch attribute except its id and tenant, and a new branch confers nothing on its own.
- **BRANCH-2 (Low, reproduced).** Three branches created in one tenant (RPC, direct at `aal2`, direct at `aal1`) produced one `branch_created` event. It is Low because nothing consumes that event, so the loss is audit and timeline only. The same direct INSERT kept a caller-supplied `created_at = 2001-01-01`; that is not part of the finding, because a caller-writable `created_at` is the schema-wide question SPEC-216 recorded for every table with such a column, no function assigns `new.created_at` on any table, SUP-5's event repair left `suppliers.created_at` caller-writable, and nothing reads `branches.created_at`.
- **Held, and pinned:** planting in or relocating into another tenant, updating another tenant's branch, a non-holder's INSERT and UPDATE, DELETE (no grant) and a duplicate slug.
- **Cross-table pass:** no door asymmetry. Every inbound reference is a composite `(tenant_id, id)` key; canon 28 makes `max_branches` unenforced on every door alike; `branch_type` free text is CAT-6's recorded position; nothing defines what an inactive branch refuses.
- **STEPUP-1 (`UNPROVEN` structural candidate class).** BRANCH-1's mechanism appears on eleven tables by a catalog criterion. Only `branches` is a reproduced, consequence-classified defect. `departments` and `tenants` were observed accepting an `aal1` owner's rename, with consequence unclassified; the other eight are structural candidates only. None of them gains a disposition or counts toward coverage.

The owner directed that this slice be recorded and not repaired. This contract replaces `changes/SPEC-225-branch-door-audit.md`, which the owner cancelled at `10e8505` because its frozen steps would have left the manifest's Batch 6 coverage line at 24 of 77 while its own disposition step moved the count to 25. No finding, evidence or test of that contract was disproven, and the investigation is not repeated.

## Risks

- Overclaiming the class. Mitigated by the register text: STEPUP-1 is recorded as a structural candidate set with its criterion and ceiling stated, and names exactly one reproduced member. Only `branches` moves coverage.
- A pinned-OPEN assertion is mistaken for a desired behaviour. Mitigated: the test's header and section comments state that assertions 6-8 and 19 record OPEN defects, not desired invariants, and fail when the finding is repaired, the precedent of LI-3 and CAMP-4.
- A restated figure left stale. Mitigated: every manifest line that restates a count this contract moves (the suite figure and the Batch 6 coverage line) has its own step; a tree-wide search found no other restatement.
- No schema, grant, policy, trigger, function or Primary write is made, so there is no deployment risk.

## Supersedes / Depends On

Supersedes `changes/SPEC-225-branch-door-audit.md`, already `Cancelled` by the owner at `10e8505` with an Execution Log entry stating why. It is terminal and is not edited by this contract; it is listed in Write Scope only because its commits lie inside this contract's unpublished range `origin/main..HEAD`, which a range Gate judges against this contract's Write Scope.

## Write Scope

- `changes/SPEC-226-branch-door-audit-record.md`
- `changes/SPEC-225-branch-door-audit.md`
- `supabase/tests/130_branch_door_audit_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/20260926140000_manifest_freeze_cannot_be_left.sql`
- `supabase/migrations/20260926120000_marketing_campaign_step_up_parity.sql`
- `supabase/tests/127_marketing_campaign_step_up_parity_test.sql`
- `supabase/tests/129_manifest_freeze_cannot_be_left_test.sql`
- `reports/evidence/primary-ledger-evidence.json`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `scripts/verify_database.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `changes/SPEC-225-branch-door-audit.md` (the cancelled predecessor and why)
- `_ORVION_CANONICAL/28_permissions_matrix.md` (MANAGE_BRANCHES; plan gating and `max_branches`); `_ORVION_CANONICAL/27_event_catalog.md` (`branch_created`)
- Current local `public.branches` policies, grants and triggers; `app.create_branch`, `app.guard_write_capability`, `app.authorize`, `app.mfa_satisfied`, `app.requires_mfa`, `app.visible_branch_ids`
- `supabase/tests/127_marketing_campaign_step_up_parity_test.sql` (CAMP-3's shape)
- `reports/master/MASTER_SURFACE_DISPOSITION.md` (`branches`, Coverage); `reports/master/MASTER_GAP_REGISTER.md` (CAMP-3, CAMP-4, SUP-5, USR-3, USR-4, CAT-6, PLAN-1)

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- github

## Additional Verification

- `pwsh -NoProfile -File scripts/verify_role_journeys.ps1`

## Pre-Approval Evidence

Change Class: Routine

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A new pgTAP file, `130_branch_door_audit_test.sql`, plan 29 | `npx supabase test db`; Check 24; Check 15 | WRITE | The file with SHA-256 `112909be25f9562f01d48b5100b197f94425b4af35d55d2c0007dfeed016d2d0` passed 29/29 alone. It is SPEC-225's file (`d7e349358ec34e59758f1efd2562786d1cbfd9d0ef34ac83ad089643c5207f61`, 30/30) less the assertion that pinned a caller-supplied `created_at` as part of BRANCH-2, which the natural repair would not have failed; it cites SPEC-226 and states that its OPEN assertions record defects. With this file and Steps 2-5 applied in a scratch worktree at the Draft, a clean reset gave Pass A `Files=130, Tests=2320, Result: PASS`, `verify_role_journeys.ps1` `120 passed, 0 failed`, Pass B `Files=130, Tests=2320, Result: PASS`, `verify_database.sql` `ALL CHECKS PASSED`, `check_database_parity_evidence.ps1` `CLEAN`, repository consistency exit 0 and `git diff --check` exit 0. It declares all ten attack classes (four `N/A` with reasons) and carries `throws_ok`, so Check 24 admits `branches` as ADVERSARIAL. |
| The suite's size, `129 files / 2291 assertions` | manifest line `Live state`; Check 15 | WRITE | Check 15 compares this figure with `supabase/tests`; with the new file the tree holds 130 files whose literal `plan(N)` values sum to 2320. Step 5 moves the figure only after re-confirming both numbers. The HTTP figure (449 across six scripts) is not re-measured and does not move. |
| Batch 6 coverage, 24 → 25 of 77 | `MASTER_SURFACE_DISPOSITION.md` Coverage (Checks 22, 24); manifest line `Batch 6 surface coverage` | WRITE | The Master record is the SSOT and moves in Step 3; the manifest restates it and moves in Step 4. No check compares the manifest line, which is why SPEC-225 missed it; Acceptance Criterion 4 now pins it. Only `branches` is newly dispositioned, so the count moves by exactly one. |
| `branches` disposition | `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24 | WRITE | Prototyped: Check 24 `all 25 surface(s) recorded ADVERSARIAL carry a declaring test file with negative assertions`; Check 22's only report was the not-yet-existing session pointer, which the committed contract resolves. |
| BRANCH-1, BRANCH-2 and STEPUP-1 | `MASTER_GAP_REGISTER.md`; Checks 2, 11, 16, 21, 25 | WRITE | Prototyped with no report from any of those checks. Each row's Owner Decision is `—`, so Check 25 adds nothing to the manifest's open-decision line; no row uses a phrase Check 16 reads as an asserted owner decision. |
| The generated API surface | `MASTER_API_CONTRACT.md`; `check_database_parity_evidence.ps1` Check L3 | VERIFY | No database object changes. Under SPEC-225 its generator reproduced it byte-identical, and on the prototype `MASTER_API_CONTRACT.md matches the live surface`, `PRIMARY PARITY EVIDENCE: CLEAN`, exit 0. Regenerated by its generator in Step 5; an identical result is recorded with no diff. |
| The recorded Primary reading | `reports/evidence/primary-ledger-evidence.json`; Check 19; `check_database_parity_evidence.ps1` | UNAFFECTED | No migration is authored and Primary is not written; the DATABASE profile validates the recorded reading, so a fresh read is not mechanically required. It was taken anyway, read-only, from Primary `vrvtsxexkiiiivlkdxzp` on 2026-09-27: ledger `230` / `be85ed1e62f6504e9b04171677d32bc8` (latest `20260926140000`), function surface `e387e49f2a68e982ec199c316179f091` / 308, and `scripts/parity_surface.sql`'s `_combined` `9c0c3de6fbb1f1c6bddc9b0b56010d3a` / 3056, each equal to the recorded value, so there is no drift and the record stays valid. |
| The cancelled predecessor | `changes/SPEC-225-branch-door-audit.md`; historical-CR immutability | UNAFFECTED | Terminal at `10e8505`; never edited by this contract. |
| Every other surface's disposition and finding | both Master records | UNAFFECTED | `departments`, `tenants`, `campaign_daily_metrics`, `exchange_rate_adjustments` and the other STEPUP-1 candidates keep their rows unchanged; the class is recorded only in the register. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| New test passes on a clean reset, in Pass A and Pass B | BEFORE_COMPLETION | NONE | NONE | Step 6 |
| Manifest suite figure equals the files and plan sum | BEFORE_COMPLETION | Step 1 | Step 5 | Step 6 |
| Manifest Batch 6 coverage equals the disposition record | BEFORE_COMPLETION | Step 3 | Step 4 | Step 6 |
| `branches` disposition resolves its session pointer and findings | BEFORE_COMPLETION | NONE | NONE | Step 6 |
| `ai-map.json` agrees with the manifest by value | BEFORE_COMPLETION | NONE | NONE | Step 6 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `branches` is already governed by its `scope_insert`, `scope_update` and `scope_read` policies, the absent DELETE grant, `branches_tenant_slug_key`, `app.create_branch`'s `app.authorize` and the child tables' `app.guard_write_capability`. No control is added or changed; the test pins those existing controls and pins the two open findings.

Added Property: `branches`' existing tenant, permission, grant and uniqueness controls, and its two open findings, are executable in the permanent suite, so a regression in any of them, or a repair of either finding, turns the suite red.

Causal Negative: In rolled-back local transactions an `aal1` owner refused by `app.create_branch` created a branch and renamed, re-slugged and deactivated Main through the table (BRANCH-1), and three creations produced one `branch_created` (BRANCH-2).

Positive Test Design: The `aal2` owner creates through the RPC (one `branch_created`) and through the table, and edits through the table.

Negative Test Design: The RPC and the child `branch_business_hours` door refuse the `aal1` owner, each pinned to `multi-factor authentication required for this role`; plant and relocation into another tenant, and a non-holder's INSERT, are refused `new row violates row-level security policy for table "branches"`; DELETE is refused `permission denied for table branches`; a duplicate slug is refused `23505`; another tenant's branch is invisible and unchanged by UPDATE; the non-holder's UPDATE changes nothing.

Non-Empty Population Obligation: The `aal1` owner holds MANAGE_BRANCHES, lacks step-up and can see the target branch; the employee lacks MANAGE_BRANCHES and can see the target branch; the other tenant's branch exists.

Mutation Obligation: Replace `scope_insert`'s WITH CHECK once without its permission conjunct and once without its tenant conjunct, each inside a savepoint; prove by md5 that each mutant is installed, prove the non-holder's INSERT lands under the first and the cross-tenant plant lands under the second, roll back, and prove the policy expression is md5-identical to the recorded original and no mutant row survived. A mutant whose installation is not proven is a harness error, never a killed mutant.

Post-Implementation Proof Obligation: A clean reset, pgTAP Pass A, `verify_role_journeys.ps1`, pgTAP Pass B, `scripts/verify_database.sql`, `check_database_parity_evidence.ps1`, repository consistency and `git diff --check` all exit 0 on the final bytes, through canonical `-Finish`.

## Implementation Steps

1. **Check** that `supabase/tests/130_branch_door_audit_test.sql` is absent. If absent, create it as one LF, transaction-rolled-back pgTAP file with `select plan(29);` and first line `-- ATTACK-CLASSES: AUTH DOOR PRIVILEGE TENANT REPLAY OBSERVABILITY STATE=N/A INPUT=N/A BUSINESS=N/A CONCURRENCY=N/A`, whose header cites SPEC-226, states each `N/A` reason, states that assertions 6-8 and 19 record OPEN defects, not desired invariants, and states that a caller-supplied `created_at` is deliberately not pinned, implementing exactly the Non-Empty Population Obligation (1-3, 20-21), the Negative and Positive Test Design (4-5, 9-18, 22-23), BRANCH-1 pinned OPEN (6-8: the `aal1` owner's direct INSERT and its rename, re-slug and deactivation land and persist, labelled as failing when repaired), BRANCH-2 pinned OPEN (19: a direct INSERT has zero `branch` events, labelled likewise) and the Mutation Obligation (24-29). The file with SHA-256 `112909be25f9562f01d48b5100b197f94425b4af35d55d2c0007dfeed016d2d0` satisfies this step. If the target exists with different content, stop.
2. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` contains `| BRANCH-1 |`. If absent, add a new dated freshness entry for Slice 24 with the previous entry demoted to `Previously:`, and append three rows after `| RFD-3 |`, each with Owner Decision `—`, Source `SPEC-226-branch-door-audit-record` and dates `09-27`: **BRANCH-1** (Low, OPEN, reproduced: cause, measured consequence bound, CAMP-3's mechanism if repaired, when priority rises, member of STEPUP-1, pinned by assertions 6-8), **BRANCH-2** (Low, OPEN, reproduced: one event for three creations, no consumer so audit and timeline only, SUP-5's mechanism if repaired, pinned by assertion 19; the kept 2001 `created_at` stated as NOT part of the finding, with the schema-wide reason) and **STEPUP-1** (severity `Unclassified`, Status `UNPROVEN — structural candidate class, recorded, deliberately not acted on`, not a reproduced class defect: the catalog criterion; the eleven candidates `branches`, `campaign_daily_metrics`, `catalog_values`, `chart_of_accounts`, `departments`, `document_retention_policies`, `exchange_rate_adjustments`, `exchange_rates`, `journal_entries`, `journal_entry_lines`, `tenants`; `user_branch_assignments` and `user_permission_grants` belonging to USR-3; `user_role_assignments` excluded by its AFTER-trigger step-up; only `branches` reproduced and consequence-classified; `aal1` renames observed landing on `departments` and `tenants` with consequence unclassified, so both remain candidates and are not audits; each member a defect only once individually reproduced and consequence-classified, and no member gaining a disposition or coverage by being listed; the criterion's ceiling; the trigger to revisit). Change no other row. If `| BRANCH-1 |` exists with different content, stop.
3. **Check** whether `reports/master/MASTER_SURFACE_DISPOSITION.md`'s `branches` row reads `NOT-RECORDED`. If so, set it to `AUDITED-OPEN` / `ADVERSARIAL` / `SPEC-226-branch-door-audit-record` / `BRANCH-1, BRANCH-2`, with a Next cell pointing to `130_branch_door_audit_test.sql` and stating what it proves, that it pins BRANCH-1 and BRANCH-2 as OPEN defects rather than desired behaviour, the non-defects swept (including `created_at` as the schema-wide question) and that BRANCH-1 is a member of STEPUP-1; update Coverage to `25 of 77 recorded · 7 AUDITED · 15 AUDITED-OPEN · 3 PARTIAL · 0 EXEMPT · 52 NOT-RECORDED` and `All 25 recorded surfaces`; add a new dated freshness entry with the previous demoted to `Previously:`. Change no other row. If the row carries any other disposition, stop.
4. **Check** whether `_ORVION_CANONICAL/manifest.md` reads `Batch 6 surface coverage: **24 of 77 surfaces have a recorded audit disposition**, all twenty-four at`. If so, and only after Step 3 has set `branches` to `AUDITED-OPEN` / `ADVERSARIAL` and the disposition record's Coverage reads `25 of 77 recorded`, change exactly that text to `Batch 6 surface coverage: **25 of 77 surfaces have a recorded audit disposition**, all twenty-five at`. Change nothing else on that line. If the line carries any other count, stop.
5. **Check** whether `_ORVION_CANONICAL/manifest.md` reads `Suite **129 files / 2291 assertions**`. If so, change only that figure to `Suite **130 files / 2320 assertions**`, after confirming `supabase/tests` holds 130 `.sql` files whose literal `plan(N)` values sum to 2320; if either number differs, stop. Then regenerate `ai-map.json` with `pwsh -NoProfile -File scripts/generate-ai-map.ps1` and store it LF, and regenerate `reports/master/MASTER_API_CONTRACT.md` with `pwsh -NoProfile -File scripts/generate-api-contract.ps1`, recording whether it is byte-identical; never hand-edit it. If the manifest carries any other suite figure, stop.
6. **Check** for a `Local certification` Execution Log entry. If absent, run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`, recording each verification's exit and the pgTAP totals. Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, set Runtime Checkpoint DONE, transition Complete, set `Last Completed` to Slice 24 and `Next capability` to Batch 6 Slice 25 ranked by `scripts/batch6_select_target.ps1`, clear `Active Change Request`, and regenerate `ai-map.json` LF. Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate, require exact-SHA candidate CI, promote the same accepted SHA, run `-Certify` for `REMOTE_CERTIFY: READY`, verify synchronized clean refs and remove permitted scratch files. Do not start Slice 25.

## Acceptance Criteria

- [x] `supabase/tests/130_branch_door_audit_test.sql` exists, declares `plan(29)` and the ten attack classes, states that its OPEN assertions record defects rather than desired invariants, does not pin a caller-supplied `created_at`, pins the tenant, permission, grant and uniqueness controls to their messages, pins BRANCH-1 and BRANCH-2 as OPEN with assertions that fail when either is repaired, and mutation-proves each `scope_insert` conjunct with a byte-identical restore.
- [x] `MASTER_GAP_REGISTER.md` holds BRANCH-1 and BRANCH-2 as Low, OPEN, reproduced findings, BRANCH-2 owning event parity only and stating that the caller-supplied `created_at` is not part of it, and STEPUP-1 with Status `UNPROVEN` as a structural candidate class that names `branches` as its only reproduced, consequence-classified member and keeps every other member a candidate; no other row changed.
- [x] `MASTER_SURFACE_DISPOSITION.md` records `branches` as `AUDITED-OPEN` / `ADVERSARIAL` with findings BRANCH-1, BRANCH-2, Coverage reads 25 of 77, and no other row changed, so no STEPUP-1 candidate gained a disposition.
- [x] `_ORVION_CANONICAL/manifest.md`'s Batch 6 surface coverage line reads `**25 of 77 surfaces have a recorded audit disposition**, all twenty-five at` `ADVERSARIAL`, equal to the disposition record's Coverage.
- [x] The manifest's suite figure reads `130 files / 2320 assertions`, `ai-map.json` agrees with the manifest by value and is stored LF, and `MASTER_API_CONTRACT.md` is byte-identical to its generator's output.
- [x] `changes/SPEC-225-branch-door-audit.md` is byte-identical to its state at `10e8505` and still reads `Cancelled`.
- [x] No file under `supabase/migrations/` changed, no database object was created, altered or dropped, Primary was not written, and Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [x] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-09-27 — Owner approval

Owner approved the exact Draft SHA `57777ca5b253cd0d7beca276717dc65070801121` and the frozen eight-path Write Scope. A read-only evaluation of the committed Draft returned `APPROVAL_EVIDENCE: PASS` (profiles DATABASE, REPOSITORY; permanent-control path `supabase/tests/130_branch_door_audit_test.sql`). Pre-approval revalidation: HEAD, Draft bytes and SPEC-225's Cancelled bytes unchanged; `origin/main` at `b6a0714`; Primary `vrvtsxexkiiiivlkdxzp` read-only ledger `230` / `be85ed1e62f6504e9b04171677d32bc8` (latest `20260926140000`) and function surface `e387e49f2a68e982ec199c316179f091` / 308, unchanged. Approval authorizes the record-only Slice 24 execution only: no repair, migration, schema change or Primary write.

### 2026-09-27 — Execution started

The approved eight-path record-only contract entered In Progress at `7da341a`. Resume Step 1. No repair, migration, schema change or Primary write is authorized.

### 2026-09-27 — Steps 1-5 executed

- Step 1: Applied — `supabase/tests/130_branch_door_audit_test.sql` created, LF, SHA-256 `112909be25f9562f01d48b5100b197f94425b4af35d55d2c0007dfeed016d2d0` (the file this step names), `plan(29)`.
- Step 2: Applied — Slice 24 freshness entry added with the previous demoted to `Previously:`; BRANCH-1, BRANCH-2 and STEPUP-1 appended after `| RFD-3 |`; no other row changed.
- Step 3: Applied — `branches` set to `AUDITED-OPEN` / `ADVERSARIAL` / `SPEC-226-branch-door-audit-record` / `BRANCH-1, BRANCH-2`; Coverage `25 of 77 recorded · 7 AUDITED · 15 AUDITED-OPEN · 3 PARTIAL · 0 EXEMPT · 52 NOT-RECORDED`; freshness entry added; no other row changed.
- Step 4: Applied — after Step 3, the manifest's Batch 6 coverage line moved to `**25 of 77 surfaces have a recorded audit disposition**, all twenty-five at`; nothing else on the line changed.
- Step 5: Applied — `supabase/tests` measured at 130 `.sql` files with a literal `plan(N)` sum of 2320, then the suite figure moved to `Suite **130 files / 2320 assertions**`; `ai-map.json` regenerated and stored LF; `MASTER_API_CONTRACT.md` regenerated by `scripts/generate-api-contract.ps1` and is byte-identical (no diff).

Repository consistency exit 0; `git diff --check` exit 0; manifest 6710 characters. No migration, no database object change, no Primary write.

### 2026-09-27 — Local certification

At `cad2371` (Resume Step DONE), canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` derived profiles DATABASE, REPOSITORY and passed every mandatory verification: `npx supabase db reset`; `npx supabase test db` (Pass A); `scripts/verify_role_journeys.ps1`; `npx supabase test db` (Pass B); `scripts/verify_database.sql`; `scripts/check_database_parity_evidence.ps1`; `scripts/check_repository_consistency.ps1`; `git diff --check`; then `LOCAL_CERTIFY: READY`. Finish keeps only PASS lines, so the totals were measured once more at `cad2371` without reset: `Files=130, Tests=2320, Result: PASS`. The same end state measured `verify_role_journeys.ps1` `120 passed, 0 failed` and `verify_database.sql` `ALL CHECKS PASSED` in the pre-approval proof. `-Gate -BaseRef origin/main` over the whole unpublished range (SPEC-225's lifecycle and this contract) returned `ORVION: READY`. Primary was read only (ledger `230` / `be85ed1e62f6504e9b04171677d32bc8`, function surface `e387e49f2a68e982ec199c316179f091` / 308, unchanged) and never written; Secondary was never contacted.

## Verification Notes

None yet.

### 2026-09-27 — Independent Review of execution commit

Verdict: Confirmed Complete

Findings: re-checked against the committed bytes, not this contract's Execution Log. AC1: the test declares `plan(29)` and the ten attack classes, states that assertions 6-8 and 19 record OPEN defects and not desired invariants, pins no `created_at`, carries 7 `throws_ok` and two `scope_insert` mutants with an md5-identical restore, and cites SPEC-226. AC2: the register range diff adds exactly three table rows; BRANCH-1 and BRANCH-2 read Low / OPEN, BRANCH-2's title is event parity only and its text says the caller-supplied `created_at` is not part of it, and STEPUP-1 reads `UNPROVEN — structural candidate class`. AC3: the disposition diff changes only the `branches` row; 25 rows are recorded, matching Coverage `25 of 77`, and `departments`, `tenants`, `catalog_values`, `chart_of_accounts`, `exchange_rates`, `journal_entries`, `journal_entry_lines` and `document_retention_policies` remain `NOT-RECORDED`. AC4: the manifest reads `**25 of 77 surfaces have a recorded audit disposition**, all twenty-five at `ADVERSARIAL``, with no `24 of 77` left. AC5: the manifest reads `Suite **130 files / 2320 assertions**`, measured; `ai-map.json` is stored LF (`git ls-files --eol`) and Check 7 is green; `MASTER_API_CONTRACT.md` is unchanged in the range and a fresh generator run leaves no diff. AC6: SPEC-225 is byte-identical to `10e8505` and reads `Cancelled`. AC7: no path under `supabase/migrations/` changed; Primary was not written; Secondary was not contacted. AC8: the range `origin/main..HEAD` touches seven paths, all in Write Scope, and the range Gate is READY.

Recommendation to human: Set Status to Complete

## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created or deleted.
- [x] No section was added, removed or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

EARN IT: BRANCH-1 and BRANCH-2 are reproduced; their consequence is measured, and it is bounded by the absence of any reader. WORTH IT: recording them costs one permanent test and three register rows; repairing BRANCH-1 alone would spend a CR and a Primary deployment on the lowest-consequence member of a class whose other members are unmeasured. The owner chose to record, not repair. Rejected: repairing `branches` now (CAMP-3's mechanism would work, but consequence does not earn it yet); repairing, reproducing or guarding the whole class inside this slice (scope expansion); giving the `departments`, `tenants` or finance rows of the disposition record a finding or a disposition (they are candidates, not audits). Draft revised after independent review: BRANCH-2 was narrowed to event parity (a caller-supplied `created_at` is SPEC-216's schema-wide question, and the assertion that pinned it would not have failed on the natural repair); STEPUP-1's Status became `UNPROVEN`, the register's own term for a recorded, unreproduced cross-table question (CAMP-2, PLACE-2), in place of `OPEN`, which the register's five-state table reserves for known, costed debt. Why this contract exists: SPEC-225 froze steps that moved the disposition record's coverage and not the manifest line restating it; the owner cancelled it rather than complete it stale or widen it after approval. PAX-8, BOOK-10, CAMP-4, ENTRY-1, PAY-3, PAY-4 and USR-3 are untouched. The registered worktree `owt/p2` is untouched.
