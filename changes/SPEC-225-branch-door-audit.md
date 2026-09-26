# Change Request — SPEC-225

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[x] Cancelled

## Objective

Record Batch 6 Slice 24's audit of `branches`: a permanent adversarial test that pins what holds and what does not, two reproduced findings, one structurally discovered class of candidates, and the surface's disposition, with no schema change.

## Business Reason

Batch 6 Slice 24 selected `branches` live at Exposure 10, coverage 584; `subscriptions` was runner-up at 10/604. Both passes were run in rolled-back local transactions.

- **BRANCH-1 (Low, reproduced).** An `owner` holding MANAGE_BRANCHES at `aal1` was refused `multi-factor authentication required for this role` by `app.create_branch` and by the child `branch_business_hours` guard, then created a branch and set the tenant's Main branch to a new name, a new slug and `is_active = false` through the table. The RPC charges `app.authorize` (permission and step-up); the table's policies charge `app.has_permission` (permission only) and no trigger on `branches` charges step-up. It is Low because nothing reads any branch attribute except its id and tenant, and a new branch confers nothing on its own.
- **BRANCH-2 (Low, reproduced).** Three branches created in one tenant (RPC, direct at `aal2`, direct at `aal1`) produced one `branch_created` event, and a direct INSERT kept `created_at = 2001-01-01`. It is Low because nothing consumes that event or that column.
- **Held, and pinned:** planting in or relocating into another tenant, updating another tenant's branch, a non-holder's INSERT and UPDATE, DELETE (no grant) and a duplicate slug.
- **Cross-table pass:** no door asymmetry. Every inbound reference is a composite `(tenant_id, id)` key; canon 28 makes `max_branches` unenforced on every door alike; `branch_type` free text is CAT-6's recorded position; nothing defines what an inactive branch refuses.
- **STEPUP-1 (class candidate, structural only).** BRANCH-1's mechanism appears on eleven tables by a catalog criterion. Only `branches` is a reproduced, consequence-classified defect; the other ten stay candidates until each is reproduced adversarially and its consequence classified.

The owner directed that this slice be recorded and not repaired.

## Risks

- Overclaiming the class. Mitigated by the register text: STEPUP-1 is recorded as a structural candidate set with its criterion and ceiling stated, and names exactly one reproduced member.
- A pinned-OPEN assertion is mistaken for a desired behaviour. Mitigated: assertions 6-8 and 19-20 are labelled OPEN and state that they fail when the finding is repaired, the precedent of LI-3 and CAMP-4.
- No schema, grant, policy, trigger, function or Primary write is made, so there is no deployment risk.

## Supersedes / Depends On

None.

## Write Scope

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
- `_ORVION_CANONICAL/28_permissions_matrix.md` (MANAGE_BRANCHES; plan gating and `max_branches`); `_ORVION_CANONICAL/27_event_catalog.md` (`branch_created`)
- Current local `public.branches` policies, grants and triggers; `app.create_branch`, `app.guard_write_capability`, `app.authorize`, `app.mfa_satisfied`, `app.requires_mfa`, `app.visible_branch_ids`
- `supabase/tests/127_marketing_campaign_step_up_parity_test.sql` (CAMP-3's shape)
- `reports/master/MASTER_SURFACE_DISPOSITION.md` (`branches`, Coverage); `reports/master/MASTER_GAP_REGISTER.md` (CAMP-3, CAMP-4, SUP-5, USR-3, USR-4, CAT-6, PLAN-1)

## Runtime Checkpoint

Resume Step: 1
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
| A new pgTAP file, `130_branch_door_audit_test.sql`, plan 30 | `npx supabase test db`; Check 24; Check 15 | WRITE | Prototype (SHA-256 `33a59530bf04c8566848629750b7686ec276b184afd8d2180f74943fb453d838`) run on a clean reset from `b6a0714`: 30/30 alone; full suite Pass A `Files=130, Tests=2321, Result: PASS`, and Pass B after the named HTTP suite identical. It declares all ten attack classes (four `N/A` with reasons) and carries `throws_ok`, so Check 24 admits `branches` as ADVERSARIAL. |
| The suite's size, `129 files / 2291 assertions` | `_ORVION_CANONICAL/manifest.md` Check 15 | WRITE | Measured on the prototype: Check 15 reported `manifest says 129 test files, supabase/tests holds 130` and `2291` against a plan sum of `2321`, so Step 4 moves the figure. The HTTP figure (449 across six scripts) is not re-measured by this contract and does not move. |
| `branches` disposition, Coverage 24 → 25 of 77 | `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24 | WRITE | Prototyped: Check 24 `all 25 surface(s) recorded ADVERSARIAL carry a declaring test file with negative assertions`; Check 22's only report was that `SPEC-225-branch-door-audit` did not yet exist, which this file resolves. |
| BRANCH-1, BRANCH-2 and STEPUP-1 | `MASTER_GAP_REGISTER.md`; Checks 2, 11, 16, 21, 25 | WRITE | Prototyped with no report from any of those checks. Each row's Owner Decision is `—`, so Check 25 adds nothing to the manifest's open-decision line; no row uses a phrase Check 16 reads as an asserted owner decision. |
| The generated API surface | `MASTER_API_CONTRACT.md`; `check_database_parity_evidence.ps1` Check L3 | VERIFY | No database object changes. Measured on the prototype: `MASTER_API_CONTRACT.md matches the live surface`, `PRIMARY PARITY EVIDENCE: CLEAN`, exit 0. Kept in scope only so its generator can repair it if it moves; never hand-edited. |
| The recorded Primary reading | `reports/evidence/primary-ledger-evidence.json`; Check 19 | UNAFFECTED | No migration is authored and Primary is not contacted. Measured: `RECOVER-1 LEDGER EVIDENCE: CLEAN` (230 migrations, `be85ed1e62f6504e9b04171677d32bc8`), matching a fresh read of Primary `vrvtsxexkiiiivlkdxzp` (230, latest `20260926140000`). |
| Every other surface's disposition and finding | both Master records | UNAFFECTED | `departments`, `tenants`, `campaign_daily_metrics`, `exchange_rate_adjustments` and the other STEPUP-1 candidates keep their rows unchanged; the class is recorded only in the register. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| New test passes on a clean reset, in Pass A and Pass B | BEFORE_COMPLETION | NONE | NONE | Step 5 |
| Manifest suite figure equals the files and plan sum | BEFORE_COMPLETION | Step 1 | Step 4 | Step 5 |
| `branches` disposition resolves its session pointer and findings | BEFORE_COMPLETION | NONE | NONE | Step 5 |
| `ai-map.json` agrees with the manifest by value | BEFORE_COMPLETION | NONE | NONE | Step 5 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `branches` is already governed by its `scope_insert`, `scope_update` and `scope_read` policies, the absent DELETE grant, `branches_tenant_slug_key`, `app.create_branch`'s `app.authorize` and the child tables' `app.guard_write_capability`. No control is added or changed; the test pins those existing controls and pins the two open findings.

Added Property: `branches`' existing tenant, permission, grant and uniqueness controls, and its two open findings, are executable in the permanent suite, so a regression in any of them, or a repair of either finding, turns the suite red.

Causal Negative: In rolled-back local transactions an `aal1` owner refused by `app.create_branch` created a branch and renamed, re-slugged and deactivated Main through the table (BRANCH-1), and three creations produced one `branch_created` with a direct `created_at` of 2001-01-01 kept (BRANCH-2).

Positive Test Design: The `aal2` owner creates through the RPC (one `branch_created`) and through the table, and edits through the table.

Negative Test Design: The RPC and the child `branch_business_hours` door refuse the `aal1` owner, each pinned to `multi-factor authentication required for this role`; plant and relocation into another tenant, and a non-holder's INSERT, are refused `new row violates row-level security policy for table "branches"`; DELETE is refused `permission denied for table branches`; a duplicate slug is refused `23505`; another tenant's branch is invisible and unchanged by UPDATE; the non-holder's UPDATE changes nothing.

Non-Empty Population Obligation: The `aal1` owner holds MANAGE_BRANCHES, lacks step-up and can see the target branch; the employee lacks MANAGE_BRANCHES and can see the target branch; the other tenant's branch exists.

Mutation Obligation: Replace `scope_insert`'s WITH CHECK once without its permission conjunct and once without its tenant conjunct, each inside a savepoint; prove by md5 that each mutant is installed, prove the non-holder's INSERT lands under the first and the cross-tenant plant lands under the second, roll back, and prove the policy expression is md5-identical to the recorded original and no mutant row survived. A mutant whose installation is not proven is a harness error, never a killed mutant.

Post-Implementation Proof Obligation: A clean reset, pgTAP Pass A, `verify_role_journeys.ps1`, pgTAP Pass B, `scripts/verify_database.sql`, `check_database_parity_evidence.ps1`, repository consistency and `git diff --check` all exit 0 on the final bytes, through canonical `-Finish`.

## Implementation Steps

1. **Check** that `supabase/tests/130_branch_door_audit_test.sql` is absent. If absent, create it as one LF, transaction-rolled-back pgTAP file with `select plan(30);` and first line `-- ATTACK-CLASSES: AUTH DOOR PRIVILEGE TENANT REPLAY OBSERVABILITY STATE=N/A INPUT=N/A BUSINESS=N/A CONCURRENCY=N/A`, whose header states each `N/A` reason, implementing exactly the Non-Empty Population Obligation (1-3, 21-22), the Negative and Positive Test Design (4-5, 9-18, 23-24), BRANCH-1 pinned OPEN (6-8: the `aal1` owner's direct INSERT and its rename, re-slug and deactivation land and persist, labelled as failing when repaired), BRANCH-2 pinned OPEN (19-20: a direct INSERT has zero `branch` events and keeps `created_at` 2001-01-01, labelled likewise) and the Mutation Obligation (25-30). The Draft prototype, SHA-256 `33a59530bf04c8566848629750b7686ec276b184afd8d2180f74943fb453d838`, satisfies this step. If the target exists with different content, stop.
2. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` contains `| BRANCH-1 |`. If absent, add a new dated freshness entry for Slice 24 with the previous entry demoted to `Previously:`, and append three rows after `| RFD-3 |`, each with Owner Decision `—`, Source `SPEC-225-branch-door-audit` and dates `09-27`: **BRANCH-1** (Low, OPEN, reproduced: cause, measured consequence bound, CAMP-3's mechanism if repaired, when priority rises, member of STEPUP-1, pinned by assertions 6-8), **BRANCH-2** (Low, OPEN, reproduced: one event for three creations, the kept 2001 date, no consumer, SUP-5's mechanism if repaired, pinned by assertions 19-20) and **STEPUP-1** (severity `Unclassified`, OPEN, a STRUCTURAL CANDIDATE SET and not a reproduced class defect: the catalog criterion; the eleven candidates `branches`, `campaign_daily_metrics`, `catalog_values`, `chart_of_accounts`, `departments`, `document_retention_policies`, `exchange_rate_adjustments`, `exchange_rates`, `journal_entries`, `journal_entry_lines`, `tenants`; `user_branch_assignments` and `user_permission_grants` belonging to USR-3; `user_role_assignments` excluded by its AFTER-trigger step-up; only `branches` reproduced and consequence-classified; `aal1` renames observed landing on `departments` and `tenants` with consequence unclassified, so both remain candidates; each member a defect only once individually reproduced and consequence-classified; the criterion's ceiling). Change no other row. If `| BRANCH-1 |` exists with different content, stop.
3. **Check** whether `reports/master/MASTER_SURFACE_DISPOSITION.md`'s `branches` row reads `NOT-RECORDED`. If so, set it to `AUDITED-OPEN` / `ADVERSARIAL` / `SPEC-225-branch-door-audit` / `BRANCH-1, BRANCH-2`, with a Next cell pointing to `130_branch_door_audit_test.sql` and stating what it proves, what it pins OPEN, the non-defects swept and that BRANCH-1 is a member of STEPUP-1; update Coverage to `25 of 77 recorded · 7 AUDITED · 15 AUDITED-OPEN · 3 PARTIAL · 0 EXEMPT · 52 NOT-RECORDED` and `All 25 recorded surfaces`; add a new dated freshness entry with the previous demoted to `Previously:`. Change no other row. If the row carries any other disposition, stop.
4. **Check** whether `_ORVION_CANONICAL/manifest.md` reads `Suite **129 files / 2291 assertions**`. If so, change only that figure to `Suite **130 files / 2321 assertions**`, after confirming `supabase/tests` holds 130 `.sql` files whose literal `plan(N)` values sum to 2321. Then regenerate `ai-map.json` with `pwsh -NoProfile -File scripts/generate-ai-map.ps1` and store it LF. Regenerate `reports/master/MASTER_API_CONTRACT.md` only if `check_database_parity_evidence.ps1` reports it stale, and never hand-edit it. If the manifest carries any other suite figure, stop.
5. **Check** for a `Local certification` Execution Log entry. If absent, run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`, recording each verification's exit and the pgTAP totals. Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, set Runtime Checkpoint DONE, transition Complete, set `Last Completed` to Slice 24 and `Next capability` to Batch 6 Slice 25 ranked by `scripts/batch6_select_target.ps1`, clear `Active Change Request`, and regenerate `ai-map.json` LF. Publish the exact committed candidate, require exact-SHA candidate CI, promote the same accepted SHA, run `-Certify` for `REMOTE_CERTIFY: READY`, verify synchronized clean refs and remove permitted scratch files. Do not start Slice 25.

## Acceptance Criteria

- [ ] `supabase/tests/130_branch_door_audit_test.sql` exists, declares `plan(30)` and the ten attack classes, pins the tenant, permission, grant and uniqueness controls to their messages, pins BRANCH-1 and BRANCH-2 as OPEN with assertions that fail when either is repaired, and mutation-proves each `scope_insert` conjunct with a byte-identical restore.
- [ ] `MASTER_GAP_REGISTER.md` holds BRANCH-1 and BRANCH-2 as Low, OPEN, reproduced findings, and STEPUP-1 as an `Unclassified` structural candidate set that names `branches` as its only reproduced, consequence-classified member and keeps every other member a candidate; no other row changed.
- [ ] `MASTER_SURFACE_DISPOSITION.md` records `branches` as `AUDITED-OPEN` / `ADVERSARIAL` with findings BRANCH-1, BRANCH-2, Coverage reads 25 of 77, and no other row changed.
- [ ] The manifest's suite figure reads `130 files / 2321 assertions`, `ai-map.json` agrees with the manifest by value and is stored LF, and `MASTER_API_CONTRACT.md` is byte-identical to its generator's output.
- [ ] No file under `supabase/migrations/` changed, no database object was created, altered or dropped, Primary was not written, and Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-09-27 — Owner approval

Owner approved the exact Draft SHA `f6a2eb82658468fd23855447a4e1dfeb62adb47f` and the frozen seven-path Write Scope. A read-only evaluation of the committed Draft returned `APPROVAL_EVIDENCE: PASS` (profiles DATABASE, REPOSITORY; permanent-control path `supabase/tests/130_branch_door_audit_test.sql`). Approval authorizes the record-only Slice 24 execution: no repair, no migration, no schema change and no Primary write. BRANCH-1 and BRANCH-2 stay Low / OPEN; STEPUP-1 stays a candidate set, with only `branches` reproduced and consequence-classified, and `departments` and `tenants` observed but unclassified; no other surface gains a disposition.

### 2026-09-27 — Execution started

The approved seven-path record-only contract entered In Progress at `e398b8f`. Resume Step 1. No repair, migration, schema change or Primary write is authorized.

### 2026-09-27 — CANCELLED (human command). Its frozen steps omit a manifest fact they make stale.

Steps 1-4 were applied to the working tree and not committed. Step 4 moved the manifest's suite figure to `130 files / 2321 assertions` after confirming 130 files and a plan sum of 2321, and `MASTER_API_CONTRACT.md` regenerated byte-identical. Before the Execute commit, the manifest line `Batch 6 surface coverage: **24 of 77 surfaces have a recorded audit disposition**, all twenty-four at `ADVERSARIAL`` was found to restate the count that Step 3 moves to 25. Step 4 says to change only the suite figure, and the Complete transition moves only `Last Completed` and `Next capability`, so completing would have left that line knowingly stale, and correcting it would have widened the approved steps. The owner chose to cancel and replace. The uncommitted work was discarded, so this contract changed no file other than itself, the manifest pointer and `ai-map.json`. No finding, evidence or test was disproven. The successor carries the same evidence, findings, test and record-only intent, plus an explicit step for the coverage line.

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

EARN IT: BRANCH-1 and BRANCH-2 are reproduced; their consequence is measured, and it is bounded by the absence of any reader. WORTH IT: recording them costs one permanent test and three register rows; repairing BRANCH-1 alone would spend a CR and a Primary deployment on the lowest-consequence member of a class whose other members are unmeasured. The owner chose to record, not repair. Rejected: repairing `branches` now (CAMP-3's mechanism would work, but consequence does not earn it yet); repairing or reproducing the whole class inside this slice (scope expansion); attaching STEPUP-1 to the `departments`, `tenants` or finance rows of the disposition record (they are candidates, not findings). PAX-8, BOOK-10, CAMP-4, ENTRY-1, PAY-3, PAY-4 and USR-3 are untouched. The registered worktree `owt/p2` is untouched.
