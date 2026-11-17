# Change Request — SPEC-311

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Batch 6 Slice 55 keeps a held document's retention finding open, so the storage executor can no longer delete a held version or report a held finding as done (RET-5). A member reads an attribution click only as a VIEW_MARKETING_DASHBOARD holder or through a lead they see (ATTR-5), and anchors a lead's first touch only to the click captured for that lead (ATTR-6). It records `branch_business_hours` with no finding and pins its door.

## Business Reason

- **Selection.** `scripts/batch6_select_target.ps1` at `ad3a7d4`, on the live local catalog, ranks `branch_business_hours` (Exposure 4), `document_storage_findings` (4) and `attribution_clicks` (3) next, all NOT-RECORDED. Under the owner's instructions of 2026-11-16, this slice's entry of 2026-11-17 grouped the selector's next three surfaces in one contract per product. Each surface keeps its own finding rows, migration or test, and disposition row. The manifest's Next capability names that selector, never a copy of its result.
- **Why it matters.**
  - `document_storage_findings` is the queue of the storage executor. `app.reconcile_document_storage` records a superseded version as a `retention_expired` candidate; `app.claim_storage_actions` hands out only unheld candidates; `app.platform_resolve_storage_finding` (SECURITY DEFINER, `service_role` only) closes a finding and, for `object_deleted`, deletes the version's metadata and writes its destroy event. A legal hold is stronger than every retention period (RET-1, RET-2, `20260909180403`).
  - `attribution_clicks` is a lead's first-touch acquisition lineage: gclid, session id, landing page and campaign. `app.capture_attribution_click` (SECURITY DEFINER, `orvion_integration` only) records a click for one lead and anchors that lead's `attribution_click_id`; `app.map_outcomes_to_conversions` turns the anchored click's gclid into the lead's offline conversion. `authenticated` holds SELECT only.
  - `branch_business_hours` holds a branch's opening hours. `authenticated` holds INSERT, SELECT and UPDATE, guarded by `app.guard_write_capability` (MANAGE_BRANCHES or MANAGE_TENANT_SETTINGS, with the second factor) and the tenant policy.
- **Measured at `ad3a7d4`** on the local stack. The fixtures were one tenant with an owner at `aal1` and `aal2`, an employee who sees one lead, a second employee who sees another, a trainee who sees none and a Giza branch manager, plus another tenant's owner, `service_role`, `orvion_integration` and anonymous REST; documents with a held and an unheld version, three captured clicks and the branches' hours.
  - **RET-5 (Medium).** A superseded version recorded as a retention candidate before the owner placed a legal hold was deleted by `app.platform_resolve_storage_finding(..., 'object_deleted')`, its destroy event written and the finding closed: the resolver releases the version reference first, so the update slips past the suppression trigger. `dismissed` and `failed` were returned as done while that trigger silently discarded both updates. The claim already skips the held document; the resolver did not read the hold.
  - **ATTR-5 (Medium).** The trainee, both employees and the branch manager each read every click of the tenant, the click of a lead they cannot see included, with its gclid, session id and campaign. The policy was `tenant_isolation` FOR ALL.
  - **ATTR-6 (Medium).** An employee set the empty first touch of the lead they handle to a click captured for another lead, and the owner at `aal2` did the same on a second lead. The lineage trigger (ATTR-3) keeps a first touch only once it is set.
  - **Why RET-5 is Medium.** RET-3's precedent: an irreversible loss of held evidence, reached only through the trusted executor between a candidate's record and its resolution.
  - **Why ATTR-5 is Medium.** DOC-9's precedent: a read across the member's own scope of identifiers that link a person to their ad and browsing session.
  - **Why ATTR-6 is Medium.** ATTR-2's precedent: attribution the product reports and sends on, set by hand.
- **The repair: one migration, `20261117120000` (RET-5, ATTR-5, ATTR-6).**
  - RET-5: the resolver refuses every resolution of a `retention_expired` finding whose document is held (23514, as the claim's own exclusion reads), so the finding stays open and claimable after the release. The body is otherwise unchanged.
  - ATTR-5: the tenant-only policy becomes a SELECT `scope_isolation` in the DOC-1/DOC-9 shape: VIEW_MARKETING_DASHBOARD holders (as `marketing_campaigns`) read the tenant's clicks; everyone else reads a click only through a lead the leads policy shows them. The FOR ALL policy granted nothing more, since there is no write grant.
  - ATTR-6: `app.guard_lead_lifecycle` (already BEFORE INSERT OR UPDATE on `leads`, SECURITY DEFINER, the platform paths exempt by `auth.uid() is null`) refuses a member setting `attribution_click_id` to anything but a click captured for this lead (42501, the lineage trigger's code). LEAD-2 and LEAD-4 are unchanged.
  - No grant, constraint, foreign key, trigger, RPC signature or event code changes.
- **`branch_business_hours` is recorded with no finding.** The door held when probed; test 177 pins it, because Check 24 needs a test that names the surface. No migration.
- **Existing files that move, each for a stated reason.**
  - `reports/master/MASTER_API_CONTRACT.md` is regenerated and moves one row: the `attribution_clicks` policy name `tenant_isolation` becomes `scope_isolation`. No RPC, signature or grant changes.
  - No existing test moves.
- **Swept and found sound, pinned rather than changed:**
  - Writing hours needs MANAGE_BRANCHES with the second factor; employees, the branch manager and the trainee are refused; no client role deletes an hours row; a foreign branch is refused by the foreign key.
  - Findings have no `authenticated` grant and a `false` policy; the resolver refuses an unknown or null code, an unknown finding and a second resolve, and counts an unheld `failed` attempt without closing it; reconciliation does not reopen a resolved finding.
  - No client role writes a click; the capture refuses another tenant's lead or campaign, an unknown source or tenant, a consent outside the set and a second gclid.
  - Another tenant reads and writes none of the three; anonymous REST is refused at each table and RPC.
- **Recorded positions, not repaired:**
  - Hours accept a day outside 0-6, closing before opening, closed with times, open without times, a second row for one day, a caller-supplied or rewritten `created_at` and a move between the tenant's branches; nothing reads the hours.
  - A `service_role` direct UPDATE can reopen a finding (platform trust).
  - The capture accepts a future `clicked_at` and a null consent from its trusted caller.
  - `offline_conversions` and `app.record_offline_conversion` are their own surfaces.
- **Latent on Primary.** `vrvtsxexkiiiivlkdxzp` holds 0 hours rows, 0 storage findings and 0 attribution clicks (read-only, 2026-11-17, ledger 268). No stored row is affected and no data repair is needed.

## Risks

- **Trigger order.** No trigger is added. `app.guard_lead_lifecycle` keeps its place among the 13 `leads` triggers, and the lineage trigger still guards a first touch already set; each decides its own column or refusal.
- **The behavior change.** A held retention finding can no longer be resolved by any code until the hold is released, which the claim already implied. A member who is not a dashboard holder no longer reads clicks of leads they cannot see, and no member anchors a first touch to another lead's click. The capture, owned by `postgres` and run by `orvion_integration`, passes through, and tests 09, 13, 36, 64, 137, 142 and 143 pass unchanged; no existing test reads a click across scope or resolves a held finding.
- **Primary deployment is irreversible.** It runs only under the exact-SHA Gate-2 record of Step 8, and approval of this contract does not authorize it. Secondary `brplkqmbzffpxqgkkdzo` is never contacted.
- **Gate 1 and Gate 2 of this contract are DELEGATED** under the owner's instructions, recorded outside this repository and never as a human-typed digest:
  - class authorization for Batch 6 releases and standing approval of proposals, 2026-11-08 ~10:20 Cairo
  - publish, promote and hosted deploy, ~12:05 Cairo
  - slice 13 in run mode 2, with the slice's own grouping decision, 2026-11-17 ~09:41 Cairo

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-311-a-held-document-keeps-its-finding-and-a-click-stays-in-scope.md`
- `supabase/migrations/20261117120000_a_held_document_keeps_its_finding_and_a_click_stays_in_scope.sql`
- `supabase/tests/175_a_held_document_keeps_its_retention_finding_open_test.sql`
- `supabase/tests/176_a_click_is_read_through_its_lead_and_anchors_only_its_lead_test.sql`
- `supabase/tests/177_branch_hours_are_written_only_by_a_tenant_settings_holder_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607041600_create_organization_tables.sql`
- `supabase/migrations/202607043000_create_marketing_and_offline_conversion_tables.sql`
- `supabase/migrations/202607043300_create_rls_policies.sql`
- `supabase/migrations/202607049400_capture_attribution_click.sql`
- `supabase/migrations/202607050600_tenant_qualified_foreign_keys.sql`
- `supabase/migrations/202607054900_document_retention_and_storage_reconciliation.sql`
- `supabase/migrations/202607055200_findings_fk_meets_referential_standard.sql`
- `supabase/migrations/202607055300_storage_executor_contract.sql`
- `supabase/migrations/202607056100_write_grants_match_the_writers.sql`
- `supabase/migrations/202607056700_acquisition_lineage_is_first_touch.sql`
- `supabase/migrations/202607061900_the_lead_door_that_answered_its_own_authority_question.sql`
- `supabase/migrations/20260909180403_a_legal_hold_always_overrides_retention.sql`
- `supabase/tests/09_conversion_delivery_lease_test.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/13_conversion_identity_snapshot_test.sql`
- `supabase/tests/26_duplicate_prevention_test.sql`
- `supabase/tests/35_subscription_write_gate_test.sql`
- `supabase/tests/36_subscription_gate_system_paths_test.sql`
- `supabase/tests/49_document_retention_test.sql`
- `supabase/tests/52_public_api_and_executor_contract_test.sql`
- `supabase/tests/53_api_surface_test.sql`
- `supabase/tests/58_write_grants_and_config_capability_test.sql`
- `supabase/tests/60_storage_backlog_observability_test.sql`
- `supabase/tests/64_acquisition_lineage_test.sql`
- `supabase/tests/97_retention_policy_per_document_type_test.sql`
- `supabase/tests/116_document_legal_hold_retention_override_test.sql`
- `supabase/tests/130_branch_door_audit_test.sql`
- `supabase/tests/135_document_version_clock_and_object_test.sql`
- `supabase/tests/136_lead_assignment_clock_and_current_handler_test.sql`
- `supabase/tests/137_conversion_sources_reach_the_pipeline_test.sql`
- `supabase/tests/142_a_google_ads_call_qualifies_as_a_phone_call_test.sql`
- `supabase/tests/143_a_conversion_is_sent_only_on_google_success_test.sql`
- `scripts/verify_database.sql`
- `scripts/generate-api-contract.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/readiness_population.ps1`
- `scripts/parity_surface.sql`
- `scripts/check_database_parity.ps1`
- `scripts/check_primary_ledger.ps1`
- `ENGINEERING_METHOD.md`
- `CR_LIFECYCLE.md`
- `changes/TEMPLATE.md`
- `reports/architecture-decision-records.md`
- `reports/future-backlog.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `supabase/migrations/202607054900_document_retention_and_storage_reconciliation.sql` (the findings queue and reconciliation)
- `supabase/migrations/202607055300_storage_executor_contract.sql` (`app.platform_resolve_storage_finding`, `app.claim_storage_actions`)
- `supabase/migrations/20260909180403_a_legal_hold_always_overrides_retention.sql` (the suppression trigger and the claim's exclusion)
- `supabase/migrations/202607043000_create_marketing_and_offline_conversion_tables.sql` (`attribution_clicks`)
- `supabase/migrations/202607043300_create_rls_policies.sql` (the tenant-only policy)
- `supabase/migrations/202607049400_capture_attribution_click.sql` (the capture)
- `supabase/migrations/202607056700_acquisition_lineage_is_first_touch.sql` (the lineage trigger, ATTR-3)
- `supabase/migrations/202607061900_the_lead_door_that_answered_its_own_authority_question.sql` (`app.guard_lead_lifecycle`)
- `changes/SPEC-119-r5-attribution-capture.md` (the capture)
- `changes/SPEC-232-lead-assignment-clock-and-current-handler.md` (the leads policy a click is read through)
- `changes/SPEC-305-a-retention-period-changes-only-with-step-up-and-a-record.md` (RET-3, the severity precedent)
- `changes/SPEC-306-a-document-is-linked-only-by-someone-who-can-read-it.md` (DOC-9, the read-scope shape and precedent)
- `reports/master/MASTER_GAP_REGISTER.md` (RET-3, DOC-9, ATTR-2, ATTR-3, DOC-1)
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`, Batch 6 method, EC-1…EC-11

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

Pass 1 Design: Three surfaces are covered in one contract.

- **`document_storage_findings`.** The resolver reads the hold as the claim does and refuses every resolution of a held retention finding, so nothing is deleted or reported done while the hold stands.
- **`attribution_clicks`.** One SELECT policy in the DOC-1/DOC-9 shape replaces the tenant-only one; `app.guard_lead_lifecycle`, already on `leads`, keeps a member's first touch to the lead's own click.
- **`branch_business_hours`.** It is recorded with no migration; test 177 pins the door as found.
- **Tests and records.**
  - Test 175 pins the claim's skip, the executor door and the resolver refusing each code on a held finding, the open finding kept, the unheld version still destroyed, and the same finding resolving after the release.
  - Test 176 pins the dashboard holder's tenant read, the branch manager's and handler's scoped reads, the other tenant's empty read, the refused foreign anchors on every door, the handler's edits of an anchored and a legacy lead, and the capture still anchoring.
  - Test 177 pins the hours grants, the owner's writes at `aal2`, and the refusals of the owner at `aal1` and `aal2` (delete), the employee, the branch manager and another tenant.
  - The register records three new rows and the disposition records the three surfaces.

Pass 2 Adversarial Review: The design was challenged on the prototype.

- **Rejected designs:**
  - **Changing the suppression trigger to raise instead of discard.** It also guards reconciliation's own writes; the resolver is the one door that released the reference first, and the claim's exclusion is the existing rule.
  - **Refusing only `object_deleted` on a held finding.** `dismissed` and `failed` were also reported as done while nothing was written (mutant 175 M1).
  - **Revoking SELECT on `attribution_clicks`.** The dashboard holders and the lead's handlers read clicks the product shows.
  - **A new trigger on `leads` for the first touch.** `app.guard_lead_lifecycle` already decides who may change a lead; a second guard would split one rule.
  - **A `branch_business_hours` migration.** The door held on every probe; a test pins it instead, and the shape positions are recorded.
  - **Copying the selector's next target into the manifest** (SPEC-270; SPEC-278's cancellation).
- **Attacks run on the final bytes.**
  - The probes, as the owner at `aal1` and `aal2`, two employees, a trainee, a branch manager, another tenant's owner, `service_role`, `orvion_integration` and anonymous REST, close all three findings and hold every swept behavior.
  - Every existing test that touches the three surfaces passes, and so does the full suite.
  - The generated API contract moves exactly one row, the `attribution_clicks` policy name.

Pass 3 Evidence Refresh: 2026-11-17.

- **Re-measured** on byte-identical files in a disposable clone of `ad3a7d4`, with the project-local CLI 3.0.0:
  - the clean reset
  - tests 175, 176 and 177 alone, and pgTAP Pass A and B
  - the three declared HTTP suites and smoke
  - the probes, before and after
  - all thirteen mutants and the two causal negatives
  - the structural fingerprints before and after
  - the API-contract generator (one row moves), the map generator and repository consistency
- **Read read-only on hosted.** Primary was read for its ledger, tenants, hours, findings and clicks.

Selected Version: SPEC-311; selected: the smallest repair that closes RET-5, ATTR-5 and ATTR-6 (the storage resolver refuses to resolve a retention finding on a held document; attribution_clicks is read by VIEW_MARKETING_DASHBOARD holders or through a lead the reader sees, the policy renamed scope_isolation; guard_lead_lifecycle lets a member anchor a first touch only to a click captured for that lead; no grant, constraint, trigger, RPC signature or event code changed; branch_business_hours audited with no finding and its door pinned by test 177), proven on byte-identical files by the full local protocol, the hostile-role probes before and after, the killed mutants and the causal negatives

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A held retention finding stays open; a click is read through its lead's scope and anchors only its own lead | the storage executor and `app.platform_resolve_storage_finding`; `public.resolve_storage_finding`; the clicks reader of every member; `app.guard_lead_lifecycle` on every leads door; `app.capture_attribution_click` | WRITE | Migration SHA-256 `6044446a9577034e6fc8420baeb505ba050bd94d23c3b61f44387255395705af`, md5 `d55cb5f785dc927b524502f8405c7d0a`, 13566 bytes, LF, ASCII. `md5(prosrc)`: the resolver `b976b79b663b408b36045d70c72d3198` → `28bf1ec800bb7f27d6cb47981a12c09a`, ACL `{postgres=X/postgres,service_role=X/postgres}`; `app.guard_lead_lifecycle` `f0aa24cc9603144b63743eac38ab0660` → `2868d2e6c834a3ca219091f21249bb35`, ACL `{postgres=X/postgres}`; each SECURITY DEFINER, mode and ACL unchanged. Policy `attribution_clicks.scope_isolation` FOR SELECT replaces `tenant_isolation`. Tests 09, 13, 36, 49, 52, 53, 60, 64, 97, 116, 135, 136, 137, 142 and 143 pass unchanged. |
| Branch business hours | `branch_business_hours`; `app.guard_write_capability` | UNAFFECTED | No grant, policy, trigger or writer changes; `app.guard_write_capability` (`f6e54cb431904e54822a4f8adc675c22`) is unchanged with its mode and ACL. Tests 10, 58 and 130 pass unchanged. |
| A clean reset holds the migration | the local stack; `supabase_migrations.schema_migrations` | WRITE | A clean reset gives 269 migrations, latest `20261117120000`, ledger `ff29e9c5acf7d70b25862941f548cf97`. Triggers unchanged: `attribution_clicks` 2, `branch_business_hours` 3, `document_storage_findings` 1, `leads` 13. Catalog 71/626. |
| Tests 175, 176 and 177 | `supabase/tests` | WRITE | Test 175: SHA-256 `ec0ee5cae44b02b65ed313e655b24529bb4f6f07f9c3f270362090e1cca1705e`, md5 `14ca893aae8dfee1aee07bb8fc3f41a9`, 9769 bytes, `plan(14)`: 14/14. Test 176: SHA-256 `f317780db9bab7437cfc377aa819245a17ba10c9affaa0aed7e22ab8c285908c`, md5 `d8b709fde24ee2cfec7a29d05d56c43d`, 11298 bytes, `plan(15)`: 15/15. Test 177: SHA-256 `ab26fe697b958df8d82c500872f48238811f4bdbe6dbe4a28f48a53b89fec46e`, md5 `dba6097fd6dc92f094ac56ab0f344b29`, 7384 bytes, `plan(11)`: 11/11. Each LF, ASCII. |
| Other tests and the suite | the full pgTAP suite; the HTTP suites; smoke | VERIFY | Pass A `Files=177, Tests=3258`, PASS; HTTP 35/0, 85/0, 122/0; Pass B 177/3258, PASS; smoke `ALL CHECKS PASSED` (78 tables, 71/626 catalog). The 177 files' literal `plan(N)` values sum to 3258. No existing test and no line of `scripts/verify_database.sql` moves. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | Before (268): functions `80f02f416e552e5ecd43d053ae6c1478`/350, triggers `764c62c6b405673cfea362c053bb9315`/337, policies `b67d466a39413a56bcbfa071b310b33a`/125, grants `5cfb09c3344a26c5513989ef3c358ff1`/188, `_combined` `22978d051e6586ecd1772b144993b6b8`/3177, equal to the recorded Primary evidence. After (269, local): functions `f7427d65b5f8ee6d9f0a360ec5717b59`/350, policies `faa0844a8f07b77634e025f4b72a4320`/125, `_combined` `20caafd5b6cde6e9002e209b0a3a3102`/3177; triggers, grants, constraints (531), columns (1134), views (16), indexes (302), status transitions (115) and RLS (79) unchanged. Step 10 writes Primary values only from fresh post-deploy readings. |
| Client API | `MASTER_API_CONTRACT.md` (Check L3); `scripts/generate-api-contract.ps1` | WRITE | No RPC is added or removed, and no signature, EXECUTE grant or table grant changes. On the final bytes the generator's output equals the verified `MASTER_API_CONTRACT.md` of this contract (270 lines), which differs from the baseline in one row: the `attribution_clicks` policy `tenant_isolation` → `scope_isolation`. Step 10 regenerates it and it must equal that output. |
| Measured state that moves | manifest `Live state` and suite figure; `primary-ledger-evidence.json`; `ai-map.json` and `repository-index.md` | WRITE | 268 → 269 migrations, latest `20261117120000`, ledger fingerprint `ff29e9c5acf7d70b25862941f548cf97`; 174 → 177 files and 3218 → 3258 assertions; coverage 63 → 66 of 78. Tables (78) and client RPCs (80) do not move. `Next capability` and `Current Module` stay unchanged (selector form). |
| The pinned manifest lines `Current Module`, `Next capability` and `Batch 6 surface coverage` | native Boot; `scripts/batch6_select_target.ps1` and `MASTER_SURFACE_DISPOSITION.md`, which own their values (GOVERNANCE.md §6 rule 10) | UNAFFECTED | Step 11 names `Current Module` and `Next capability` only to leave them unchanged. Each line keeps its ratified text and pin. |
| RET-5, ATTR-5 and ATTR-6 fixed; three surfaces recorded | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24, 25, 29 | WRITE | No RET-5, ATTR-5 or ATTR-6 row exists at `ad3a7d4`. Tests 175, 176 and 177 each declare the ten classes with their N/A classes reasoned and carry negative assertions; 175 names `document_storage_findings`, 176 names `attribution_clicks`, and 177 names `branch_business_hours`, so Check 24 admits `ADVERSARIAL` for all three. Each new row has Owner `—` and is settled. Coverage 66: 42 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 12 `NOT-RECORDED`; all 66 `ADVERSARIAL`. |
| Repository consistency | `scripts/check_repository_consistency.ps1` | VERIFY | With Steps 1–6 applied and the contract present, consistency reports exactly the measured-state items: 268 vs 269 migrations, the latest version, the ledger fingerprint, 174 vs 177 files, 3218 vs 3258 assertions, and the Primary-evidence record. Checks 21–29 pass. Step 10 makes the measured-state items true, and the one implementation commit is made only after it. |
| The four CI-only guard self-tests | `scripts/test_*_guard.ps1`; `orvion-acceptance` | VERIFY | The scripts are unchanged. `orvion-acceptance` runs them on the exact candidate SHA before `main` may move to it. Their controls require the measured state of Step 10, so they are not run locally (timed once in slice 47: 618 s locally, 84 s in hosted CI). |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 9 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| The applied files equal the verified bytes, and the focused tests, probes, mutants and causal negatives hold | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 7 |
| Primary lacks the target migration, and its ledger and structure equal the recorded evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 9 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 10 | Step 11 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 2 | Step 10 | Step 11 |
| The map and the API contract match their generators | BEFORE_COMPLETION | Step 1 | Step 10 | Step 11 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: Nothing keeps the resolver off a held finding, scopes a click read to the reader's leads, or keeps a member's first touch to the lead's own click.

- `app.claim_storage_actions` skips a held document, but the resolver takes any finding id from its trusted caller.
- The suppression trigger discards a held retention row's update, but the resolver releases the version reference first, and a discarded update is still reported as done.
- `tenant_isolation` limits a click read to the tenant, not to the leads the reader sees.
- The lineage trigger keeps a first touch once set, not which click may set it.

Added Property: For every caller:

- a `retention_expired` finding on a held document is refused every resolution (23514) and stays open and claimable after the release;
- a member reads a click only as a VIEW_MARKETING_DASHBOARD holder or through a lead the leads policy shows them;
- a member sets a lead's `attribution_click_id` only to a click captured for that lead (42501).

The platform paths, the capture among them, pass through by `auth.uid() is null`.

Causal Negative: On the `ad3a7d4` schema (the stack reset to `20261116120000`), test 175 fails assertions 4 through 9 (12 of its 14 run), test 176 fails assertions 2, 4, 5, 7, 10, 13 and 14, and test 177 passes 11/11: it pins a door that held, with no migration. With the repaired function bodies and policy replaced by the pre-repair ones on the repaired stack, tests 175 and 176 fail the same sets. There, the probes delete a held version through the resolver, report `dismissed` and `failed` as done, show every click to every member, and accept another lead's click as a first touch.

Positive Test Design: Positive controls:

- Test 175: two tenants with invoice documents and a 30-day period; the scan records both old versions as candidates; the unheld version is destroyed and returns `object_deleted`; after the owner releases the hold, the same open finding resolves `object_deleted`.
- Test 176: the owner, a dashboard holder, reads all three clicks; the handler sees the leads assigned to them and edits an anchored and a legacy lead; the capture anchors a lead with its own click.
- Test 177: the owner at `aal2` sets and edits Monday's hours, and an employee reads them.

Negative Test Design: by attack class, as follows.
- **Door:** the executor door `public.resolve_storage_finding` refuses a held finding like the resolver; a lead's first touch is refused on INSERT and UPDATE alike; hours are written only by a settings holder on every door.
- **State:** a held finding stays open, unresolved and unaged after each refused code; the claim skips it; the first touch of an anchored lead is unchanged.
- **Input:** each of `object_deleted`, `dismissed`, `failed` and `object_restored` is refused on a held finding (23514); a click captured for another lead or for no lead is refused as a first touch (42501).
- **Privilege:** the handler, the owner at `aal2` and a member inserting a lead cannot anchor another lead's click (42501); the branch manager and the handler read only their leads' clicks; no client role deletes an hours row, the owner at `aal2` included; the owner at `aal1`, an employee and a branch manager cannot write hours (42501).
- **Auth and tenant:** another tenant's owner reads no click and no hours row and cannot add one (42501).
- **Replay:** releasing the hold lets the same open finding resolve once.
- **Concurrency, business and observability:** N/A, each reasoned in the tests' headers.

Non-Empty Population Obligation: Each test's fixture holds its tenants, branches, departments, users, roles and rows before the first assertion: in 175 two tenants, a held and an unheld document with old versions and their recorded findings; in 176 two tenants, two branches, four leads, three captured clicks and the assignments; in 177 two tenants, a branch, an employee, an owner, a branch manager and another tenant's owner. Each refusal is asserted by its SQLSTATE, and each kept value by its exact field.

Mutation Obligation: Each mutant is installed inside its test's own rolled-back transaction, proven installed by a diag line (the md5 of the slice functions, the table's trigger count, its UPDATE and DELETE grants, its row level security and its policy), run, and rolled back. The restored shape is read after the last mutant. A mutant not proven installed is a harness error, never a kill.

| Mutant | Change | Killed on the prototype by |
| --- | --- | --- |
| 175 M1 | only `object_deleted` refused on a held finding | 175 assertions 6, 7 and 8 |
| 175 M2 | the hold read on the wrong finding type | 175 assertions 4 through 9 |
| 176 M1 | the read tenant-only | 176 assertions 2, 4 and 5 |
| 176 M2 | dashboard holders lose the tenant read | 176 assertion 1 |
| 176 M3 | no read through a visible lead | 176 assertions 2, 4, 7 and 10 |
| 176 M4 | any attached click read | 176 assertions 2, 4 and 5 |
| 176 M5 | the first touch not guarded | 176 assertions 7, 10, 13 and 14 |
| 176 M6 | any click of the tenant anchors | 176 assertions 7, 10, 13 and 14 |
| 176 M7 | an unchanged first touch rechecked | 176 assertion 9 |
| 177 M1 | DELETE granted to `authenticated` | 177 assertions 1, 4, 6, 7 and 9 |
| 177 M2 | the capability guard dropped | 177 assertions 5, 6, 7, 8 and 9 |
| 177 M3 | tenant isolation opened | 177 assertions 10 and 11 |
| 177 M4 | row level security disabled | 177 assertions 10 and 11 |

Post-Implementation Proof Obligation: All of the following on the final bytes, through canonical `-Finish` from the main checkout with the project-local CLI:

- the clean reset, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke;
- the generated artifacts, repository consistency and the recorded Primary evidence.

Before Step 9: the focused tests, the probes, the mutants, the causal negatives and the fresh Primary baseline of Step 7.

## Implementation Steps

1. Check whether `supabase/migrations/20261117120000_a_held_document_keeps_its_finding_and_a_click_stays_in_scope.sql` contains `RET-5, ATTR-5, ATTR-6 -- Batch 6 slice 55`; if so record Already Applied when its Git blob is cac36174e8c9bbd4423192815da9c65611dd03e7, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the migration: the storage resolver refuses a held retention finding, attribution_clicks read through scope, and a first touch anchored only to the lead's own click), and change nothing else:

   ```text
   -- RET-5, ATTR-5, ATTR-6 -- Batch 6 slice 55 (`document_storage_findings`, `attribution_clicks`).
   --
   -- THE RULE. A legal hold is stronger than every configured retention period (RET-1/RET-2,
   -- `20260909180403`): while a document is held no version of it enters the retention-deletion
   -- queue and an already-recorded candidate may not be claimed. `app.platform_resolve_storage_finding`
   -- (SECURITY DEFINER, `service_role` only) closes a finding and, for `retention_expired` +
   -- `object_deleted`, deletes the version's metadata. An attribution click is first-touch acquisition
   -- lineage: `app.capture_attribution_click` (SECURITY DEFINER, `orvion_integration` only) records it
   -- for one lead and anchors that lead's `attribution_click_id`; `authenticated` holds SELECT only.
   -- Measured before this migration (local stack, `probe-02.log`):
   --   RET-5   on a retention finding recorded before the hold was placed, the resolver deleted the
   --           held document's version and wrote its destroy event (`object_deleted`: releasing the
   --           version reference first slips past the suppression trigger), and returned `dismissed`
   --           and `failed` as done while that trigger silently discarded both updates -- the claim
   --           excludes held documents, the resolver did not;
   --   ATTR-5  a trainee, an employee and a branch manager each read every click of the tenant, gclid,
   --           session id and landing page included, for leads their own scope does not show them
   --           (the policy was tenant-only);
   --   ATTR-6  an employee and the owner set a lead's empty first touch to a click captured for
   --           ANOTHER lead; the lineage trigger guards only a value already set.
   --
   -- THE REPAIR, in existing shapes.
   --   RET-5   the resolver refuses every resolution of a `retention_expired` finding whose document
   --           is held (23514, as the claim's own exclusion reads), so the finding stays open and
   --           claimable after the release. The body is otherwise unchanged.
   --   ATTR-5  the tenant-only policy becomes a SELECT `scope_isolation` in the DOC-1/DOC-9 shape: the
   --           marketing dashboard holders (VIEW_MARKETING_DASHBOARD, as `marketing_campaigns`) read
   --           the tenant's clicks; everyone else reads a click only through a lead the leads policy
   --           shows them. The FOR ALL policy granted nothing more: there is no write grant.
   --   ATTR-6  `app.guard_lead_lifecycle` (already BEFORE INSERT OR UPDATE on leads, SECURITY DEFINER,
   --           the platform paths exempt by `auth.uid() is null`) refuses a member setting
   --           `attribution_click_id` to anything but a click captured for this lead (42501, the
   --           lineage trigger's code). LEAD-2 and LEAD-4 are unchanged.
   --
   -- NOT CHANGED: every grant, constraint, foreign key and trigger; `app.capture_attribution_click`,
   -- `app.claim_storage_actions`, `app.reconcile_document_storage` and the suppression trigger.
   -- Positions recorded, not repaired here: `branch_business_hours` (audited: no range, order,
   -- closed-with-times or (branch, day) uniqueness check, `created_at` writable, a row may move between
   -- branches of the tenant; nothing reads the hours); the capture accepts a future `clicked_at` and a
   -- null consent from its trusted platform caller; a `service_role` direct UPDATE can reopen a
   -- finding (platform trust); `offline_conversions` and `app.record_offline_conversion` are their
   -- own surfaces.

   create or replace function app.platform_resolve_storage_finding(p_finding_id uuid, p_resolution_code text, p_note text default null::text)
   returns text
   language plpgsql
   security definer
   set search_path to ''
   as $function$
   declare
       v_f record;
   begin
       select * into v_f
       from public.document_storage_findings
       where id = p_finding_id;
       if not found then
           raise exception 'unknown finding %', p_finding_id;
       end if;
       if v_f.resolved_at is not null then
           raise exception 'finding % is already resolved', p_finding_id;
       end if;
       if not exists (select 1 from public.catalog_values
                       where catalog_type_code = 'document_storage_finding_resolution'
                         and code = p_resolution_code and is_active) then
           raise exception 'unknown resolution code: %', p_resolution_code;
       end if;

       -- RET-5. A legal hold is stronger than retention (RET-1/RET-2): the claim already skips a held
       -- document's candidate, and the resolver refuses it too, for every resolution. Deleting would
       -- destroy held evidence; a dismissal or a failure would be discarded by the suppression trigger
       -- while this function reported it as done.
       if v_f.finding_type_code = 'retention_expired'
          and exists (select 1
                        from public.document_versions dv
                        join public.documents d
                          on d.tenant_id = dv.tenant_id and d.id = dv.document_id
                       where dv.tenant_id = v_f.tenant_id
                         and dv.id = v_f.document_version_id
                         and d.legal_hold_active) then
           raise exception 'the document of finding % is under legal hold; its retention finding stays open until the hold is released',
                           p_finding_id
               using errcode = 'check_violation';
       end if;

       -- FND-1. A failure is an ATTEMPT, not an outcome. It records what happened and returns without
       -- touching `resolved_at`, so the finding is still open, still claimable, and still counted.
       if p_resolution_code = 'failed' then
           update public.document_storage_findings
              set attempt_count   = attempt_count + 1,
                  last_attempt_at = now(),
                  last_error      = p_note
            where id = p_finding_id;
           return 'failed';
       end if;

       -- The metadata removal. Deliberately narrow: only a retention-expired finding, only on a
       -- confirmed deletion. An `orphan_object` finding has no version row to remove, and a
       -- `missing_object` finding must NOT remove one -- the object is what is missing, and the
       -- metadata is the only remaining evidence that it ever existed.
       if v_f.finding_type_code = 'retention_expired' and p_resolution_code = 'object_deleted' then
           if v_f.document_version_id is not null then
               -- THE SUBSCRIPTION GATE APPLIES TO THIS DELETE, AND IS CHECKED HERE RATHER THAN
               -- TRIPPED OVER. `document_versions_enforce_document_subscription_gate` fires BEFORE
               -- DELETE and has NO system-path exemption; WP-03 settled deliberately that the gate is
               -- the boundary and batch callers skip lapsed tenants
               -- (`36_subscription_gate_system_paths_test.sql`). Refusing explicitly turns an opaque
               -- 42501 from a trigger three layers down into a message the executor can act on.
               -- Consequence, stated: a tenant that never returns to good standing keeps its
               -- superseded versions forever. That is RET-2, a business decision, not a guess.
               if not app.subscription_allows_write(v_f.tenant_id) then
                   raise exception
                       'tenant % is in a restricted subscription state; its stored data is frozen '
                       'for reading and export only, so this version will not be destroyed',
                       v_f.tenant_id
                       using errcode = 'insufficient_privilege';
               end if;

               -- Re-check eligibility at the moment of destruction rather than trusting the finding.
               -- A version can have been promoted back to current between the scan and this call, and
               -- destroying the live version of a document because a day-old finding said so is
               -- exactly the irreversible mistake this whole package exists to prevent.
               if exists (select 1
                            from public.document_versions dv
                            join public.documents d
                              on d.tenant_id = dv.tenant_id and d.id = dv.document_id
                           where dv.id = v_f.document_version_id
                             and (dv.is_current or d.current_version_id = dv.id)) then
                   raise exception 'version % is current again and will not be destroyed',
                                   v_f.document_version_id;
               end if;

               -- Release the references BEFORE the delete (`202607055200`: the FK is RESTRICT, and the
               -- Referential Action Standard has no exception for this table).
               update public.document_storage_findings
                  set document_version_id = null
                where document_version_id = v_f.document_version_id;

               delete from public.document_versions where id = v_f.document_version_id;

               perform app.record_event(
                   v_f.tenant_id, 'document_archived', 'document',
                   (v_f.details ->> 'document_id')::uuid, null,
                   'superseded', 'destroyed',
                   'retention window elapsed; object destroyed by the storage executor',
                   jsonb_build_object('storage_path', v_f.storage_path,
                                      'version_number', v_f.details -> 'version_number',
                                      'retention_days', v_f.details -> 'retention_days'),
                   'warning');
           end if;
       end if;

       update public.document_storage_findings
          set resolved_at = now(),
              resolution_code = p_resolution_code,
              resolution_note = p_note,
              last_attempt_at = now()
        where id = p_finding_id;

       return p_resolution_code;
   end;
   $function$;

   drop policy tenant_isolation on public.attribution_clicks;

   create policy scope_isolation on public.attribution_clicks
       for select to authenticated
       using (
           tenant_id = (select app.current_tenant_id())
           and (
               (select app.has_permission('VIEW_MARKETING_DASHBOARD'))
               or (lead_id is not null
                   and exists (select 1 from public.leads l
                                where l.id = attribution_clicks.lead_id
                                  and l.tenant_id = attribution_clicks.tenant_id))
           )
       );

   create or replace function app.guard_lead_lifecycle()
   returns trigger
   language plpgsql
   security definer
   set search_path to ''
   as $function$
   begin
       -- Platform/system paths (canon 35 principle 6): seeds, migrations, `service_role` and the
       -- session-less jobs build lead state directly and are outside per-table enforcement.
       if (select auth.uid()) is null then
           return new;
       end if;

       -- ATTR-6. The first touch is the click captured FOR THIS LEAD. `app.capture_attribution_click`
       -- is the only writer of a click and anchors it; the lineage trigger keeps a value once set, and
       -- this keeps a member from setting an empty one to a click captured for another lead.
       if new.attribution_click_id is not null
          and (tg_op = 'INSERT' or old.attribution_click_id is distinct from new.attribution_click_id)
          and not exists (
              select 1 from public.attribution_clicks c
              where c.id = new.attribution_click_id
                and c.tenant_id = new.tenant_id
                and c.lead_id = new.id
          )
       then
           raise exception
               'a lead''s first touch is the click captured for that lead (app.capture_attribution_click); '
               'click % was not captured for lead %',
               new.attribution_click_id, new.id
               using errcode = '42501';
       end if;

       -- LEAD-2. A lead enters the pipeline at `new`. Not invented: `app.create_lead` is the only
       -- sanctioned writer and hardcodes it, and canon 26 makes `new` the initial state. Without this
       -- the transition graph is enforced only for leads that entered through the graph.
       if tg_op = 'INSERT' and new.lead_status_code is distinct from 'new' then
           raise exception
               'a lead enters the pipeline at ''new'' (canon 26); it was created as ''%'' -- use '
               'app.assign_lead / app.advance_lead / app.convert_lead to move it',
               new.lead_status_code
               using errcode = '23514';
       end if;

       -- LEAD-4. `assigned -> contacted` is CAUSED, not chosen. It is the one edge no RPC offers:
       -- `app.advance_lead` refuses it by name, and `app.record_lead_interaction` produces it only as a
       -- consequence of a qualifying interaction. Flipping it by hand takes the lead out of
       -- `app.process_lead_sla`'s working set (it scans `lead_status_code = 'assigned'`) with no
       -- evidence of contact anywhere.
       --
       -- The qualifying set is transcribed from `app.record_lead_interaction`, which took it from
       -- canon 26. This asks only that the evidence EXIST -- it does not decide LI-3's open question of
       -- whether a direct INSERT should itself advance the lifecycle.
       if tg_op = 'UPDATE'
          and old.lead_status_code = 'assigned' and new.lead_status_code = 'contacted'
          and not exists (
              select 1 from public.lead_interactions li
              where li.lead_id = new.id
                and li.tenant_id = new.tenant_id
                and li.interaction_type_code in
                    ('phone_call', 'whatsapp_message', 'chat_opened', 'customer_reply')
          )
       then
           raise exception
               'a lead becomes ''contacted'' by a qualifying interaction, not by assertion (canon 10/26); '
               'use app.record_lead_interaction'
               using errcode = '23514';
       end if;

       return new;
   end;
   $function$;
   ```

   The resulting file's Git blob is cac36174e8c9bbd4423192815da9c65611dd03e7.

2. Check whether `supabase/tests/175_a_held_document_keeps_its_retention_finding_open_test.sql` contains `plan(14)`; if so record Already Applied when its Git blob is 11afba06cdc320d6353b5cd88a72d1cb64d65732, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (test 175, 14 assertions), and change nothing else:

   ```text
   -- pgTAP: Batch 6 slice 55 (document_storage_findings) --
   -- RET-5: a legal hold stops every resolution of a retention finding recorded before the hold, so a
   -- held version is never destroyed and its finding is neither closed nor aged while the hold stands.
   -- ATTACK-CLASSES: AUTH=N/A TENANT DOOR STATE INPUT=N/A CONCURRENCY=N/A REPLAY PRIVILEGE=N/A BUSINESS=N/A OBSERVABILITY=N/A
   --   AUTH, PRIVILEGE=N/A -- the resolver is `service_role` only and `authenticated` holds no grant on
   --     the table (tests 49, 52 and 60 pin both); this file is about what the platform caller may do.
   --   INPUT=N/A -- an unknown or null code, an unknown finding and a second resolve are refused
   --     before the hold check, unchanged (test 49).
   --   CONCURRENCY=N/A -- the hold and the resolve each take the finding's row; the claim already
   --     skips a held document, and the resolver now rechecks at the moment of destruction.
   --   BUSINESS=N/A -- a finding carries no money.
   --   OBSERVABILITY=N/A -- the destroy event is unchanged; a refusal writes nothing.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(14);

   insert into auth.users (id, email) values
     ('17500000-0000-0000-0000-0000000000a1','owner@c175.test');
   insert into public.tenants (id, name, slug, status) values
     ('17500000-0000-0000-0000-000000000001','Held Travel','held-travel-175','active'),
     ('17500000-0000-0000-0000-000000000002','Free Travel','free-travel-175','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select v.t, sp.id, 'active' from public.subscription_plans sp,
     (values ('17500000-0000-0000-0000-000000000001'::uuid), ('17500000-0000-0000-0000-000000000002')) v(t)
   where sp.plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug) values
     ('17500000-0000-0000-0000-00000000000a','17500000-0000-0000-0000-000000000001','Giza','giza-175');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
     ('17500000-0000-0000-0000-0000000000c1','17500000-0000-0000-0000-000000000001','17500000-0000-0000-0000-00000000000a','operations','Operations');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('17500000-0000-0000-0000-000000000011','17500000-0000-0000-0000-000000000001','Owner','owner@c175.test',true,'17500000-0000-0000-0000-0000000000a1');
   insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
     ('17500000-0000-0000-0000-000000000001','17500000-0000-0000-0000-000000000011','17500000-0000-0000-0000-00000000000a','17500000-0000-0000-0000-0000000000c1',true);
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select '17500000-0000-0000-0000-000000000001', '17500000-0000-0000-0000-000000000011', r.id, 'tenant'
   from public.roles r where r.code = 'owner';

   insert into public.documents (id, tenant_id, document_type_code, title, lifecycle_status_code) values
     ('17500000-0000-0000-0000-0000000000d1','17500000-0000-0000-0000-000000000001','invoice','Held invoice','active'),
     ('17500000-0000-0000-0000-0000000000d2','17500000-0000-0000-0000-000000000002','invoice','Free invoice','active');
   insert into public.document_versions
     (id, tenant_id, document_id, version_number, file_name, file_type_code, storage_path, is_current, uploaded_at) values
     ('17500000-0000-0000-0000-0000000000f1','17500000-0000-0000-0000-000000000001','17500000-0000-0000-0000-0000000000d1',1,'a-old.pdf','pdf','17500000-0000-0000-0000-000000000001/17500000-0000-0000-0000-0000000000d1/1-a-old.pdf',false,now()-interval '400 days'),
     ('17500000-0000-0000-0000-0000000000f2','17500000-0000-0000-0000-000000000001','17500000-0000-0000-0000-0000000000d1',2,'a-current.pdf','pdf','17500000-0000-0000-0000-000000000001/17500000-0000-0000-0000-0000000000d1/2-a-current.pdf',true,now()-interval '400 days'),
     ('17500000-0000-0000-0000-0000000000f3','17500000-0000-0000-0000-000000000002','17500000-0000-0000-0000-0000000000d2',1,'b-old.pdf','pdf','17500000-0000-0000-0000-000000000002/17500000-0000-0000-0000-0000000000d2/1-b-old.pdf',false,now()-interval '400 days'),
     ('17500000-0000-0000-0000-0000000000f4','17500000-0000-0000-0000-000000000002','17500000-0000-0000-0000-0000000000d2',2,'b-current.pdf','pdf','17500000-0000-0000-0000-000000000002/17500000-0000-0000-0000-0000000000d2/2-b-current.pdf',true,now()-interval '400 days');
   update public.documents set current_version_id = '17500000-0000-0000-0000-0000000000f2' where id = '17500000-0000-0000-0000-0000000000d1';
   update public.documents set current_version_id = '17500000-0000-0000-0000-0000000000f4' where id = '17500000-0000-0000-0000-0000000000d2';
   insert into storage.objects (bucket_id, name)
   select 'documents', storage_path from public.document_versions where tenant_id in
     ('17500000-0000-0000-0000-000000000001','17500000-0000-0000-0000-000000000002');
   insert into public.document_retention_policies (tenant_id, document_type_code, retention_days, reason) values
     ('17500000-0000-0000-0000-000000000001','invoice',30,'test-approved period'),
     ('17500000-0000-0000-0000-000000000002','invoice',30,'test-approved period');

   -- The scan runs BEFORE the hold: the candidate is recorded while the document is free.
   select app.reconcile_document_storage();
   select set_eq(
     $$select document_version_id::text from public.document_storage_findings
        where finding_type_code = 'retention_expired'
          and tenant_id in ('17500000-0000-0000-0000-000000000001','17500000-0000-0000-0000-000000000002')$$,
     $$values ('17500000-0000-0000-0000-0000000000f1'), ('17500000-0000-0000-0000-0000000000f3')$$,
     'CONTROL: the scan before the hold records both old versions as retention candidates');

   select set_config('request.jwt.claims', '{"sub":"17500000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
   set local role authenticated;
   select lives_ok(
     $$select app.set_document_legal_hold('17500000-0000-0000-0000-0000000000d1', true, 'litigation notice received')$$,
     'the owner places the hold after the candidate was recorded');
   reset role;
   select set_config('request.jwt.claims', '', true);

   select is((select count(*)::int from app.claim_storage_actions(500) where tenant_id = '17500000-0000-0000-0000-000000000001'),
     0, 'CONTROL: the claim already skips the held candidate');

   set local role service_role;
   select throws_ok(
     $$select public.resolve_storage_finding(
         (select id from public.document_storage_findings where document_version_id = '17500000-0000-0000-0000-0000000000f1'),
         'object_deleted', 'executor deleted the object')$$,
     '23514', null, 'the executor''s door refuses to destroy a held document''s version');
   reset role;
   select throws_ok(
     $$select app.platform_resolve_storage_finding(
         (select id from public.document_storage_findings where document_version_id = '17500000-0000-0000-0000-0000000000f1'),
         'object_deleted', null)$$,
     '23514', null, 'the resolver refuses object_deleted while the hold stands');
   select throws_ok(
     $$select app.platform_resolve_storage_finding(
         (select id from public.document_storage_findings where document_version_id = '17500000-0000-0000-0000-0000000000f1'),
         'dismissed', null)$$,
     '23514', null, 'the resolver refuses to dismiss a held candidate');
   select throws_ok(
     $$select app.platform_resolve_storage_finding(
         (select id from public.document_storage_findings where document_version_id = '17500000-0000-0000-0000-0000000000f1'),
         'failed', 'timeout')$$,
     '23514', null, 'the resolver refuses to count an attempt on a held candidate');
   select throws_ok(
     $$select app.platform_resolve_storage_finding(
         (select id from public.document_storage_findings where document_version_id = '17500000-0000-0000-0000-0000000000f1'),
         'object_restored', null)$$,
     '23514', null, 'the resolver refuses object_restored on a held candidate');

   select is(
     (select f.resolved_at is null and f.resolution_code is null and f.attempt_count = 0
        and exists (select 1 from public.document_versions where id = '17500000-0000-0000-0000-0000000000f1')
        from public.document_storage_findings f where f.document_version_id = '17500000-0000-0000-0000-0000000000f1'),
     true, 'the held version still exists and its finding is open, unresolved and not aged');

   select is(
     app.platform_resolve_storage_finding(
       (select id from public.document_storage_findings where document_version_id = '17500000-0000-0000-0000-0000000000f3'),
       'object_deleted', null),
     'object_deleted', 'POSITIVE CONTROL: the unheld tenant''s candidate is destroyed as before');
   select is((select count(*)::int from public.document_versions where id = '17500000-0000-0000-0000-0000000000f3'),
     0, 'the unheld version''s metadata is gone');

   select set_config('request.jwt.claims', '{"sub":"17500000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
   set local role authenticated;
   select lives_ok(
     $$select app.set_document_legal_hold('17500000-0000-0000-0000-0000000000d1', false, 'counsel released the hold')$$,
     'the owner releases the hold');
   reset role;
   select set_config('request.jwt.claims', '', true);

   select is(
     app.platform_resolve_storage_finding(
       (select id from public.document_storage_findings
         where tenant_id = '17500000-0000-0000-0000-000000000001' and finding_type_code = 'retention_expired' and resolved_at is null),
       'object_deleted', null),
     'object_deleted', 'RELEASE: the same open finding is resolved once the hold is released');
   select is((select count(*)::int from public.document_versions where id = '17500000-0000-0000-0000-0000000000f1'),
     0, 'the released version''s metadata is gone');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 11afba06cdc320d6353b5cd88a72d1cb64d65732.

3. Check whether `supabase/tests/176_a_click_is_read_through_its_lead_and_anchors_only_its_lead_test.sql` contains `plan(15)`; if so record Already Applied when its Git blob is 1a091b7848ead9adc544c1ab92ec8dd89af29284, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (test 176, 15 assertions), and change nothing else:

   ```text
   -- pgTAP: Batch 6 slice 55 (attribution_clicks) --
   -- ATTR-5: a member reads a click only through a lead their own scope shows them; the marketing
   -- dashboard holders read the tenant's clicks. ATTR-6: a member never sets a lead's first touch to a
   -- click captured for another lead or for none; the platform capture still anchors it.
   -- ATTACK-CLASSES: AUTH=N/A TENANT DOOR STATE INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS=N/A OBSERVABILITY=N/A
   --   AUTH=N/A -- reading clicks needs no aal2: the leads that reveal them need none either.
   --   CONCURRENCY, REPLAY=N/A -- the guard reads the click row it names; a click's lead never
   --     changes (no write grant on clicks), so no race moves it.
   --   BUSINESS=N/A -- a click carries no money; the offline conversion is its own surface.
   --   OBSERVABILITY=N/A -- a refused write records nothing; the lineage trigger is unchanged.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(15);

   insert into auth.users (id, email) values
     ('17600000-0000-0000-0000-0000000000a1','emp@c176.test'),
     ('17600000-0000-0000-0000-0000000000a2','bm@c176.test'),
     ('17600000-0000-0000-0000-0000000000a4','owner@c176.test'),
     ('17600000-0000-0000-0000-0000000000a5','other@c176.test');
   insert into public.tenants (id, name, slug, status) values
     ('17600000-0000-0000-0000-000000000001','Click Travel','click-travel-176','active'),
     ('17600000-0000-0000-0000-000000000002','Other Travel','other-travel-176','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select t, sp.id, 'active'
   from public.subscription_plans sp,
        unnest(array['17600000-0000-0000-0000-000000000001'::uuid,
                     '17600000-0000-0000-0000-000000000002'::uuid]) t
   where sp.plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug) values
     ('17600000-0000-0000-0000-00000000000a','17600000-0000-0000-0000-000000000001','Cairo','cairo-176'),
     ('17600000-0000-0000-0000-00000000000b','17600000-0000-0000-0000-000000000001','Alexandria','alex-176');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
     ('17600000-0000-0000-0000-0000000000c1','17600000-0000-0000-0000-000000000001','17600000-0000-0000-0000-00000000000a','sales','Cairo Sales'),
     ('17600000-0000-0000-0000-0000000000c2','17600000-0000-0000-0000-000000000001','17600000-0000-0000-0000-00000000000b','sales','Alexandria Sales');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('17600000-0000-0000-0000-000000000011','17600000-0000-0000-0000-000000000001','Handler','emp@c176.test',true,'17600000-0000-0000-0000-0000000000a1'),
     ('17600000-0000-0000-0000-000000000012','17600000-0000-0000-0000-000000000001','Branch Manager','bm@c176.test',true,'17600000-0000-0000-0000-0000000000a2'),
     ('17600000-0000-0000-0000-000000000013','17600000-0000-0000-0000-000000000001','Owner','owner@c176.test',true,'17600000-0000-0000-0000-0000000000a4'),
     ('17600000-0000-0000-0000-000000000014','17600000-0000-0000-0000-000000000002','Other Owner','other@c176.test',true,'17600000-0000-0000-0000-0000000000a5');
   insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
   select '17600000-0000-0000-0000-000000000001', u,
          '17600000-0000-0000-0000-00000000000a','17600000-0000-0000-0000-0000000000c1', true
   from unnest(array['17600000-0000-0000-0000-000000000011'::uuid,
                     '17600000-0000-0000-0000-000000000012'::uuid]) u;
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select v.t, v.u, r.id, 'tenant'
   from (values ('17600000-0000-0000-0000-000000000001'::uuid,'17600000-0000-0000-0000-000000000011'::uuid,'employee'),
                ('17600000-0000-0000-0000-000000000001','17600000-0000-0000-0000-000000000012','branch_manager'),
                ('17600000-0000-0000-0000-000000000001','17600000-0000-0000-0000-000000000013','owner'),
                ('17600000-0000-0000-0000-000000000002','17600000-0000-0000-0000-000000000014','owner')) v(t,u,rc)
   join public.roles r on r.code = v.rc;

   -- e1 Cairo (the handler's), e2 Alexandria (outside the handler's and the Cairo manager's scope),
   -- e3 Cairo with no first touch yet.
   insert into public.leads (id, tenant_id, branch_id, department_id, lead_source_code, title, lead_status_code) values
     ('17600000-0000-0000-0000-0000000000e1','17600000-0000-0000-0000-000000000001','17600000-0000-0000-0000-00000000000a','17600000-0000-0000-0000-0000000000c1','google_ads_call','Cairo lead','new'),
     ('17600000-0000-0000-0000-0000000000e2','17600000-0000-0000-0000-000000000001','17600000-0000-0000-0000-00000000000b','17600000-0000-0000-0000-0000000000c2','google_ads_call','Alexandria lead','new'),
     ('17600000-0000-0000-0000-0000000000e3','17600000-0000-0000-0000-000000000001','17600000-0000-0000-0000-00000000000a','17600000-0000-0000-0000-0000000000c1','google_ads_call','Untouched lead','new'),
     ('17600000-0000-0000-0000-0000000000e4','17600000-0000-0000-0000-000000000001','17600000-0000-0000-0000-00000000000a','17600000-0000-0000-0000-0000000000c1','google_ads_call','Legacy lead','new');

   select app.capture_attribution_click(p_tenant_id => '17600000-0000-0000-0000-000000000001',
     p_attribution_source_code => 'google_ads', p_gclid => 'GCLID-176-CAIRO',
     p_lead_id => '17600000-0000-0000-0000-0000000000e1');
   select app.capture_attribution_click(p_tenant_id => '17600000-0000-0000-0000-000000000001',
     p_attribution_source_code => 'google_ads', p_gclid => 'GCLID-176-ALEX',
     p_lead_id => '17600000-0000-0000-0000-0000000000e2');
   select app.capture_attribution_click(p_tenant_id => '17600000-0000-0000-0000-000000000001',
     p_attribution_source_code => 'google_ads', p_gclid => 'GCLID-176-NOLEAD');
   -- A legacy row: a platform path (auth.uid() null) anchored e4 to a click not captured for it.
   update public.leads set attribution_click_id = (select id from public.attribution_clicks where gclid = 'GCLID-176-NOLEAD')
    where id = '17600000-0000-0000-0000-0000000000e4';

   select set_config('request.jwt.claims','{"sub":"17600000-0000-0000-0000-0000000000a2"}', true);
   set local role authenticated;
   select app.assign_lead('17600000-0000-0000-0000-0000000000e1','17600000-0000-0000-0000-000000000011','fixture');
   select app.assign_lead('17600000-0000-0000-0000-0000000000e3','17600000-0000-0000-0000-000000000011','fixture');

   -- ATTR-5: who reads which click.
   select set_config('request.jwt.claims','{"sub":"17600000-0000-0000-0000-0000000000a4"}', true);
   select set_eq($$select gclid from public.attribution_clicks$$,
     $$values ('GCLID-176-CAIRO'), ('GCLID-176-ALEX'), ('GCLID-176-NOLEAD')$$,
     'the owner (a marketing dashboard holder) reads every click of the tenant');

   select set_config('request.jwt.claims','{"sub":"17600000-0000-0000-0000-0000000000a2"}', true);
   select set_eq($$select gclid from public.attribution_clicks$$, $$values ('GCLID-176-CAIRO')$$,
     'the Cairo branch manager reads only the click of a Cairo lead');

   select set_config('request.jwt.claims','{"sub":"17600000-0000-0000-0000-0000000000a1"}', true);
   select set_eq($$select id::text from public.leads$$,
     $$values ('17600000-0000-0000-0000-0000000000e1'), ('17600000-0000-0000-0000-0000000000e3'), ('17600000-0000-0000-0000-0000000000e4')$$,
     'CONTROL: the handler''s scope shows the three Cairo leads and not the Alexandria one');
   select set_eq($$select gclid from public.attribution_clicks$$, $$values ('GCLID-176-CAIRO')$$,
     'the handler reads only the click of a lead they see: not Alexandria''s, not the unattached one');
   select is((select count(*)::int from public.attribution_clicks where gclid = 'GCLID-176-ALEX'),
     0, 'the handler cannot read another branch''s click even by its gclid');

   select set_config('request.jwt.claims','{"sub":"17600000-0000-0000-0000-0000000000a5"}', true);
   select is((select count(*)::int from public.attribution_clicks
               where tenant_id = '17600000-0000-0000-0000-000000000001'), 0,
     'another tenant''s owner reads none of the tenant''s clicks');

   -- ATTR-6: the first touch is only the click captured for that lead.
   select set_config('request.jwt.claims','{"sub":"17600000-0000-0000-0000-0000000000a1"}', true);
   select throws_ok(
     $$update public.leads set attribution_click_id =
         (select lead_click.id from public.attribution_clicks lead_click where lead_click.gclid = 'GCLID-176-CAIRO')
        where id = '17600000-0000-0000-0000-0000000000e3'$$,
     '42501', null, 'the handler cannot give a lead the first touch of another lead');
   select lives_ok(
     $$update public.leads set title = 'Cairo lead, renamed' where id = '17600000-0000-0000-0000-0000000000e1'$$,
     'the handler still edits an anchored lead: the guard reads only a change of the first touch');
   select lives_ok(
     $$update public.leads set title = 'Legacy lead, renamed' where id = '17600000-0000-0000-0000-0000000000e4'$$,
     'the handler still edits a legacy lead whose first touch a platform path set before this guard');
   select throws_ok(
     $$insert into public.leads (tenant_id, branch_id, department_id, lead_source_code, title, lead_status_code, attribution_click_id)
       values ('17600000-0000-0000-0000-000000000001','17600000-0000-0000-0000-00000000000a','17600000-0000-0000-0000-0000000000c1',
               'google_ads_call','Borrowed touch','new',
               (select c.id from public.attribution_clicks c where c.gclid = 'GCLID-176-CAIRO'))$$,
     '42501', null, 'a member cannot create a lead carrying another lead''s first touch');

   select set_config('request.jwt.claims','{"sub":"17600000-0000-0000-0000-0000000000a4"}', true);
   select throws_ok(
     $$update public.leads set attribution_click_id =
         (select c.id from public.attribution_clicks c where c.gclid = 'GCLID-176-ALEX')
        where id = '17600000-0000-0000-0000-0000000000e3'$$,
     '42501', null, 'not even the owner moves another lead''s click onto a lead');
   select throws_ok(
     $$update public.leads set attribution_click_id =
         (select c.id from public.attribution_clicks c where c.gclid = 'GCLID-176-NOLEAD')
        where id = '17600000-0000-0000-0000-0000000000e3'$$,
     '42501', null, 'not even the owner claims an unattached click as a lead''s first touch');

   reset role;
   select set_config('request.jwt.claims', '', true);
   select is((select attribution_click_id from public.leads where id = '17600000-0000-0000-0000-0000000000e3'),
     null, 'the untouched lead still has no first touch');

   select app.capture_attribution_click(p_tenant_id => '17600000-0000-0000-0000-000000000001',
     p_attribution_source_code => 'meta_ads', p_gclid => 'GCLID-176-OWN',
     p_lead_id => '17600000-0000-0000-0000-0000000000e3');
   select is((select attribution_click_id from public.leads where id = '17600000-0000-0000-0000-0000000000e3'),
     (select id from public.attribution_clicks where gclid = 'GCLID-176-OWN'),
     'POSITIVE CONTROL: the platform capture anchors the lead to the click captured for it');
   select is((select attribution_click_id from public.leads where id = '17600000-0000-0000-0000-0000000000e1'),
     (select id from public.attribution_clicks where gclid = 'GCLID-176-CAIRO'),
     'the handler''s edit left the first lead''s first touch where the capture put it');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 1a091b7848ead9adc544c1ab92ec8dd89af29284.

4. Check whether `supabase/tests/177_branch_hours_are_written_only_by_a_tenant_settings_holder_test.sql` contains `plan(11)`; if so record Already Applied when its Git blob is b58da8e600750ad93e1544b28426a59a2d977e95, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (test 177, 11 assertions), and change nothing else:

   ```text
   -- pgTAP: Batch 6 slice 55 (branch_business_hours) --
   -- a branch's hours are written only by a holder of MANAGE_BRANCHES at aal2, in its own tenant (no
   -- migration: the door held when probed, so this file pins it).
   -- ATTACK-CLASSES: AUTH TENANT DOOR STATE=N/A INPUT=N/A CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS=N/A OBSERVABILITY=N/A
   --   STATE=N/A -- an hours row has no lifecycle: no status and no archive.
   --   INPUT=N/A -- a day outside 0-6, closing before opening, closed with times, two rows for one
   --     branch and day, a written `created_at` and a move between the tenant's branches are recorded
   --     positions: no function, policy or view reads the hours, so none changes what any reader
   --     decides.
   --   CONCURRENCY, REPLAY=N/A -- each row is its own row; adding one twice is two rows, and nothing
   --     reads them.
   --   BUSINESS=N/A -- hours carry no money.
   --   OBSERVABILITY=N/A -- hours record no event on any door; a recorded position (tenant settings
   --     that nothing reads).
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(11);

   insert into auth.users (id, email) values
     ('17700000-0000-0000-0000-0000000000a1','employee@c177.test'),
     ('17700000-0000-0000-0000-0000000000a2','owner@c177.test'),
     ('17700000-0000-0000-0000-0000000000a3','manager@c177.test'),
     ('17700000-0000-0000-0000-0000000000a4','other@c177.test');
   insert into public.tenants (id, name, slug, status) values
     ('17700000-0000-0000-0000-000000000001','Hours Travel','hours-travel-177','active'),
     ('17700000-0000-0000-0000-000000000002','Other Travel','other-travel-177','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select v.t, sp.id, 'active' from public.subscription_plans sp,
     (values ('17700000-0000-0000-0000-000000000001'::uuid), ('17700000-0000-0000-0000-000000000002')) v(t)
   where sp.plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug) values
     ('17700000-0000-0000-0000-00000000000a','17700000-0000-0000-0000-000000000001','Giza','giza-177');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
     ('17700000-0000-0000-0000-0000000000c1','17700000-0000-0000-0000-000000000001','17700000-0000-0000-0000-00000000000a','sales','Giza Sales');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('17700000-0000-0000-0000-000000000011','17700000-0000-0000-0000-000000000001','Employee','employee@c177.test',true,'17700000-0000-0000-0000-0000000000a1'),
     ('17700000-0000-0000-0000-000000000012','17700000-0000-0000-0000-000000000001','Owner','owner@c177.test',true,'17700000-0000-0000-0000-0000000000a2'),
     ('17700000-0000-0000-0000-000000000013','17700000-0000-0000-0000-000000000001','Manager','manager@c177.test',true,'17700000-0000-0000-0000-0000000000a3'),
     ('17700000-0000-0000-0000-000000000014','17700000-0000-0000-0000-000000000002','Other','other@c177.test',true,'17700000-0000-0000-0000-0000000000a4');
   insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
     ('17700000-0000-0000-0000-000000000001','17700000-0000-0000-0000-000000000011','17700000-0000-0000-0000-00000000000a','17700000-0000-0000-0000-0000000000c1',true),
     ('17700000-0000-0000-0000-000000000001','17700000-0000-0000-0000-000000000013','17700000-0000-0000-0000-00000000000a','17700000-0000-0000-0000-0000000000c1',true);
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select v.t, v.u, r.id, 'tenant'
   from (values
     ('17700000-0000-0000-0000-000000000001'::uuid, '17700000-0000-0000-0000-000000000011'::uuid, 'employee'),
     ('17700000-0000-0000-0000-000000000001', '17700000-0000-0000-0000-000000000012', 'owner'),
     ('17700000-0000-0000-0000-000000000001', '17700000-0000-0000-0000-000000000013', 'branch_manager'),
     ('17700000-0000-0000-0000-000000000002', '17700000-0000-0000-0000-000000000014', 'owner')) v(t, u, c)
   join public.roles r on r.code = v.c;

   select is(
     (select string_agg(p || '=' || has_table_privilege('authenticated', 'public.branch_business_hours', p), ' ' order by p)
      from unnest(array['DELETE', 'INSERT', 'SELECT', 'UPDATE']) p),
     'DELETE=false INSERT=true SELECT=true UPDATE=true', 'the grants are unchanged: hours are added and edited, never deleted');

   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"17700000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
   select lives_ok(
     $$insert into public.branch_business_hours (id, tenant_id, branch_id, day_of_week, opens_at, closes_at) values
       ('17700000-0000-0000-0000-0000000000e1','17700000-0000-0000-0000-000000000001','17700000-0000-0000-0000-00000000000a',1,'09:00','17:00')$$,
     'the owner at aal2 sets Monday''s hours');
   select lives_ok(
     $$update public.branch_business_hours set closes_at = '18:00' where id = '17700000-0000-0000-0000-0000000000e1'$$,
     'the owner at aal2 edits them');
   select throws_ok(
     $$delete from public.branch_business_hours where id = '17700000-0000-0000-0000-0000000000e1'$$,
     '42501', null, 'not even the owner at aal2 deletes an hours row');

   select set_config('request.jwt.claims', '{"sub":"17700000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
   select throws_ok(
     $$insert into public.branch_business_hours (tenant_id, branch_id, day_of_week, opens_at, closes_at) values
       ('17700000-0000-0000-0000-000000000001','17700000-0000-0000-0000-00000000000a',2,'09:00','17:00')$$,
     '42501', null, 'the owner at aal1 is refused: a branch setting needs the second factor');

   select set_config('request.jwt.claims', '{"sub":"17700000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
   select is(
     (select count(*)::int from public.branch_business_hours where tenant_id = '17700000-0000-0000-0000-000000000001'),
     1, 'an employee reads the tenant''s hours');
   select throws_ok(
     $$update public.branch_business_hours set opens_at = '06:00' where id = '17700000-0000-0000-0000-0000000000e1'$$,
     '42501', null, 'an employee cannot change the hours');

   select set_config('request.jwt.claims', '{"sub":"17700000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
   select throws_ok(
     $$insert into public.branch_business_hours (tenant_id, branch_id, day_of_week, opens_at, closes_at) values
       ('17700000-0000-0000-0000-000000000001','17700000-0000-0000-0000-00000000000a',3,'09:00','17:00')$$,
     '42501', null, 'a branch manager cannot set even their own branch''s hours');
   select throws_ok(
     $$update public.branch_business_hours set closes_at = '23:00' where id = '17700000-0000-0000-0000-0000000000e1'$$,
     '42501', null, 'a branch manager cannot change their own branch''s hours');

   select set_config('request.jwt.claims', '{"sub":"17700000-0000-0000-0000-0000000000a4","aal":"aal2"}', true);
   select is(
     (select count(*)::int from public.branch_business_hours where tenant_id = '17700000-0000-0000-0000-000000000001'),
     0, 'another tenant''s owner sees none of the tenant''s hours');
   select throws_ok(
     $$insert into public.branch_business_hours (tenant_id, branch_id, day_of_week, opens_at, closes_at) values
       ('17700000-0000-0000-0000-000000000001','17700000-0000-0000-0000-00000000000a',4,'09:00','17:00')$$,
     '42501', null, 'another tenant''s owner cannot set the tenant''s hours');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is b58da8e600750ad93e1544b28426a59a2d977e95.

5. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `| ATTR-5 |`; if so record Already Applied when its Git blob is 388675e6cf2a4a8377bf6891ce499a8bfe93c1d5, and otherwise stop and report. Otherwise make exactly these 3 edits (the Slice 55 freshness entry and three new rows), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-16 (**Slice 54 — `customer_notes`, `notifications` and `holidays` selected live at Exposure 5, 5 and 4, coverage 38, 64 and 8, in one contract (P1's grouping, 2026-11-16).** **CUST-15** (Medium) and **CUST-16** (Low) are new and fixed. A customer note was rewritten, blanked, moved to another customer or back-dated at the table door by someone other than its author, unrecorded and still naming that author, and a blank note was accepted there. SPEC-310 keeps every note with its customer and its text with its author, and trims and requires the text on every door. `notifications` and `holidays` were audited with no finding. No other row changed.)
   ```
   with
   ```text
   Last updated: 2026-11-17 (**Slice 55 — `branch_business_hours`, `document_storage_findings` and `attribution_clicks` selected live at Exposure 4, 4 and 3, coverage 14, 34 and 42, in one contract (P1's grouping, 2026-11-17).** **RET-5**, **ATTR-5** and **ATTR-6** (each Medium) are new and fixed. The storage resolver deleted a held document's version when its retention finding was recorded before the hold; every member read every attribution click of the tenant, gclid and session ids included; and a member set a lead's empty first touch to a click captured for another lead. SPEC-311 keeps a held finding open, scopes a click to the dashboard holders and the leads a member may see, and anchors a first touch only to its own click. `branch_business_hours` was audited with no finding. No other row changed.)

   Previously: 2026-11-16 (**Slice 54 — `customer_notes`, `notifications` and `holidays` selected live at Exposure 5, 5 and 4, coverage 38, 64 and 8, in one contract (P1's grouping, 2026-11-16).** **CUST-15** (Medium) and **CUST-16** (Low) are new and fixed. A customer note was rewritten, blanked, moved to another customer or back-dated at the table door by someone other than its author, unrecorded and still naming that author, and a blank note was accepted there. SPEC-310 keeps every note with its customer and its text with its author, and trims and requires the text on every door. `notifications` and `holidays` were audited with no finding. No other row changed.)
   ```

   b) immediately after the line
   ```text
   | ATTR-2 | **Eight actor columns are still accepted from the caller — and the detector that found them was still shaped like a name** | integrity / attribution | Medium | R | 6 | A | ✅ | **✅ FIXED 2026-09-01 (`202607059300`) — and the count was wrong in BOTH directions.** Of the eight, **four were engineering-owned and are closed**: `payments.received_by`, `customer_identity_merges.merged_by`, `booking_items.cancelled_by` and `booking_items.no_show_recorded_by`. **Two more were never in the list at all**, because the predicate that produced it asks for columns ending `_by` and these do not: **`lead_interactions.user_id`** (who made the call) and **`customers.first_registered_user_id`** (who first took the customer on). Both were reproduced and both are closed. **And the remaining four are not open work of the same kind** — `invoices.voided_by` / `journal_entries.voided_by` are **VOID-1**, an open OWNER decision (voiding is unimplemented, and deriving an attribution for an act nobody can perform would dress a missing capability as a solved one — migration `202607056500` reached this conclusion first and it still holds); `payments.verified_by` is **VERIFY-1**; and `tenant_license_activations` is granted to `postgres` and `service_role` ONLY, so no tenant caller can reach it by any door. **The whole class was decided by measurement, not by the suffix**: every one of the six closed columns has EXACTLY ONE producer, that producer already recorded the caller, and NONE accepts an actor as a parameter — so a direct write naming somebody else was unreachable through every authorized path. **`payments.received_by` in particular was NOT assumed** (this row had flagged it as possibly a legitimate business fact): `app.record_payment` and `app.record_supplier_payment` set `received_by = created_by = v_actor` with no parameter between them, no view or function READS the column, canon 31 says only "received_by nullable", and no permission distinguishes receiving from recording — so "A received the cash, B recorded it" is not expressible in ORVION today, and if it is ever wanted it is a new capability with a parameter and a permission, not a silent default. **Reproduced with live positive AND negative controls, six scenarios**, the sharpest being a finance_manager who genuinely holds RECORD_PAYMENT inserting a payment that recorded the EMPLOYEE as receiver while ATTR-1's trigger corrected `created_by` in the same statement — one column derived, the other accepted verbatim. `guard_financial_capability` watches `amount` and nothing else, so rewriting who received money needed **no capability at all** (`UPDATE 1`). `booking_items` is tied to the ACT rather than merely re-attributed: an employee had stamped a canceller on an item still `confirmed`, and re-attributing that would have traded one false statement for another. Guard: `87_actor_attribution_second_door_test.sql` (29), PAR-4 mutation-tested, plus the cross-path sweep proving all five RPCs still attribute identically. Original text follows, kept because it is what specified the work: **RECORDED AND PINNED, NOT YET FIXED.** Found by widening `83_actor_attribution_test.sql` assertion 22 from a hand-written name list to *every* column ending `_by`: `booking_items.cancelled_by`, `booking_items.no_show_recorded_by`, `customer_identity_merges.merged_by`, `invoices.voided_by`, `journal_entries.voided_by`, `payments.received_by`, `payments.verified_by`, `tenant_license_activations.consumed_by`. **This is the same detector failure twice over:** the first sweep enumerated five names, found ONE gap (FX-2) and looked finished; adding `assigned_by` produced FX-3; adding `reviewed_by` produced FX-4; asking the schema instead produced these eight. Not fixed in this package because each needs its own reproduction and a semantic judgment the others did not — `payments.received_by` may be a legitimate BUSINESS fact (which staff member physically received the cash, recordable on another's behalf) rather than a session actor, and guessing would invent policy. Assertion 22 now pins the inventory and **fails in either direction**, so a new unattributed column fails it and each fix must delete its own line | — | session-2026-08-31-batch6-care | 08-31 | 08-31 |
   ```
   insert
   ```text
   | ATTR-5 | **Every member read every attribution click of the tenant, gclid, session id and landing page included, for leads their own scope does not show them** | CRM marketing · privacy scope | Medium | R | 6 | M | 🛡 | **FIXED 2026-11-17 locally (SPEC-311, `20261117120000`); Primary deployment pending.** **MEASURED** at `ad3a7d4`: a `trainee` who sees no lead, an employee who sees one lead and a `branch_manager` each read all three of the tenant's clicks, including the click of a lead in another branch and its `campaign_id`; the policy was `tenant_isolation` FOR ALL with SELECT granted on every column. Severity is Medium by DOC-9's precedent: a read across the member's own scope of identifiers that link a person to their ad and browsing session. **Repaired:** the tenant-only FOR ALL policy became a SELECT `scope_isolation` in the DOC-1/DOC-9 shape: a VIEW_MARKETING_DASHBOARD holder reads the tenant's clicks, as `marketing_campaigns` reads; everyone else reads a click only through a lead the leads policy shows them, so an unattached click is the dashboard's alone. `app.guard_lead_lifecycle` (already BEFORE INSERT OR UPDATE on `leads`, the platform paths exempt) refuses a member setting a lead's `attribution_click_id` to anything but a click captured for that lead (42501, the lineage trigger's code); an unchanged first touch is not rechecked, and `app.capture_attribution_click` still anchors it. No grant moved. `176_a_click_is_read_through_its_lead_and_anchors_only_its_lead_test.sql` pins both. | — | SPEC-311-a-held-document-keeps-its-finding-and-a-click-stays-in-scope | 11-17 | 11-17 |
   | ATTR-6 | **A member set a lead's empty first touch to a click captured for another lead** | CRM marketing · integrity · attribution | Medium | R | 6 | M | 🛡 | **FIXED 2026-11-17 locally (SPEC-311, `20261117120000`); Primary deployment pending.** **MEASURED** at `ad3a7d4`: an employee re-pointed the first touch of a lead they handle to a click captured for another lead, and the `owner` at `aal2` did the same on a second lead; both stood. The lineage trigger (ATTR-3) keeps a first touch once set, so a lead whose capture had not run was open, and `app.map_outcomes_to_conversions` turns the anchored click's gclid into that lead's offline conversion. Severity is Medium by ATTR-2's precedent: attribution the product reports and sends on is set by hand. **Repaired:** the tenant-only FOR ALL policy became a SELECT `scope_isolation` in the DOC-1/DOC-9 shape: a VIEW_MARKETING_DASHBOARD holder reads the tenant's clicks, as `marketing_campaigns` reads; everyone else reads a click only through a lead the leads policy shows them, so an unattached click is the dashboard's alone. `app.guard_lead_lifecycle` (already BEFORE INSERT OR UPDATE on `leads`, the platform paths exempt) refuses a member setting a lead's `attribution_click_id` to anything but a click captured for that lead (42501, the lineage trigger's code); an unchanged first touch is not rechecked, and `app.capture_attribution_click` still anchors it. No grant moved. `176_a_click_is_read_through_its_lead_and_anchors_only_its_lead_test.sql` pins both. | — | SPEC-311-a-held-document-keeps-its-finding-and-a-click-stays-in-scope | 11-17 | 11-17 |
   ```

   c) immediately after the line
   ```text
   | RET-4 | **No change to a document retention policy was recorded, and an UPDATE kept the creator's name, so a file deletion could not be traced to whoever set its period** | audit completeness · observability | Medium | R | 6 | M | ✅ | **✅ FIXED 2026-11-11 (SPEC-305, `20261111150000`), DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-305; the fresh Primary ledger, functions and structure equal local.** **MEASURED** at `53146b3`: no trigger or function recorded a policy's creation, shortening, re-type or deactivation (tenant events unchanged across all of them), and `app.derive_created_by` keeps `created_by` on UPDATE, so after the ceo's shortening the row still named the owner. The legal hold, the other retention lever, records every transition as critical (canon 27). **Repaired:** `app.guard_document_retention_policy_write` (BEFORE INSERT OR UPDATE, SECURITY DEFINER, session writes only) charges `app.authorize('MANAGE_TENANT_SETTINGS')`, the legal hold's own charge, on every column; `app.emit_document_retention_policy_change` (AFTER INSERT OR UPDATE) records the new code `document_retention_policy_changed` (critical) with the actor and the previous and current type, period, active flag and reason. `164_a_retention_period_changes_only_with_step_up_and_a_record_test.sql` pins both. A no-change update and a session-less write record nothing. | — | SPEC-305-a-retention-period-changes-only-with-step-up-and-a-record | 11-11 | 11-11 |
   ```
   insert
   ```text
   | RET-5 | **The storage resolver deleted a held document's version when its retention finding was recorded before the hold** | retention · legal hold · data integrity | Medium | R | 6 | M | 🛡 | **FIXED 2026-11-17 locally (SPEC-311, `20261117120000`); Primary deployment pending.** **MEASURED** at `ad3a7d4`: a document's superseded version was recorded as a `retention_expired` candidate, the `owner` at `aal2` then placed a legal hold, and the platform caller of `app.platform_resolve_storage_finding` resolved the finding `object_deleted`: the held version's metadata was deleted, a destroy event written and the finding closed, because the resolver releases the version reference first and so slips past the suppression trigger. `dismissed` and `failed` were returned as done while that trigger silently discarded both updates. The claim (`app.claim_storage_actions`) and the suppression trigger already skip a held document; the resolver, the last step before destruction, did not read the hold. Severity is Medium by RET-3's precedent: an irreversible loss of held evidence, reached only through the trusted executor in the window between a candidate's claim and its resolution. **Repaired:** `app.platform_resolve_storage_finding` refuses every resolution of a `retention_expired` finding whose document is under legal hold (23514, the reading the claim's own exclusion already makes), so the held version stays, the executor is told instead of a false success, its finding stays open and unaged, and the same finding is resolved as before once the hold is released. The body is otherwise unchanged; no grant, trigger or event moved. `175_a_held_document_keeps_its_retention_finding_open_test.sql` pins it. | — | SPEC-311-a-held-document-keeps-its-finding-and-a-click-stays-in-scope | 11-17 | 11-17 |
   ```

   The resulting file's Git blob is 388675e6cf2a4a8377bf6891ce499a8bfe93c1d5.

6. Check whether `reports/master/MASTER_SURFACE_DISPOSITION.md` contains `**66 of 78 recorded · 42 `; if so record Already Applied when its Git blob is 74068baae6f3cd17764f6384ec56fdaef3a4f473, and otherwise stop and report. Otherwise make exactly these 6 edits (the freshness entry, coverage 66 of 78 and the three surface rows), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-16 (**slice 54 — `customer_notes`, `notifications` and `holidays` selected by Exposure 5, 5 and 4, coverage 38, 64 and 8, in one contract.** Coverage **60 → 63 of 78**. CUST-15 and CUST-16: a customer note was rewritten, blanked, moved to another customer or back-dated at the table door by someone other than its author, unrecorded, and a blank note was accepted there. SPEC-310 closes both here; `notifications` and `holidays` hold with no finding, so the three rows are `AUDITED`.)
   ```
   with
   ```text
   Last updated: 2026-11-17 (**slice 55 — `branch_business_hours`, `document_storage_findings` and `attribution_clicks` selected by Exposure 4, 4 and 3, coverage 14, 34 and 42, in one contract.** Coverage **63 → 66 of 78**. RET-5: the storage resolver deleted a held document's version; ATTR-5: every member read every click of the tenant; ATTR-6: a member anchored a lead's first touch to another lead's click. SPEC-311 closes all three here; `branch_business_hours` holds with no finding, so the three rows are `AUDITED`.)

   Previously: 2026-11-16 (**slice 54 — `customer_notes`, `notifications` and `holidays` selected by Exposure 5, 5 and 4, coverage 38, 64 and 8, in one contract.** Coverage **60 → 63 of 78**. CUST-15 and CUST-16: a customer note was rewritten, blanked, moved to another customer or back-dated at the table door by someone other than its author, unrecorded, and a blank note was accepted there. SPEC-310 closes both here; `notifications` and `holidays` hold with no finding, so the three rows are `AUDITED`.)
   ```

   b) replace the line
   ```text
   **63 of 78 recorded · 39 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 15 `NOT-RECORDED`.**
   ```
   with
   ```text
   **66 of 78 recorded · 42 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 12 `NOT-RECORDED`.**
   ```

   c) replace the line
   ```text
   **All 63 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```
   with
   ```text
   **All 66 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```

   d) replace the line
   ```text
   | `attribution_clicks` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `attribution_clicks` | **AUDITED** | ADVERSARIAL | `SPEC-311-a-held-document-keeps-its-finding-and-a-click-stays-in-scope` | ATTR-5, ATTR-6 | `176_a_click_is_read_through_its_lead_and_anchors_only_its_lead_test.sql` (15 assertions; TENANT, DOOR, STATE, INPUT and PRIVILEGE declared, the rest N/A) proves that the `owner` (a marketing dashboard holder) reads every click of the tenant; that a `branch_manager` and an employee read only the clicks of leads their scope shows, not an unattached click and not another branch's click even by its gclid; that another tenant reads none; that a member cannot give a lead another lead's or an unattached click as its first touch, while an anchored or legacy lead is still edited; and that the platform capture anchors the lead to its own click. Tests 09, 10, 13, 26, 36, 58, 64, 137 and 143 pass unchanged. **Swept and classified as non-defects:** no client role inserts, rewrites or deletes a click (no grant); `app.capture_attribution_click` is executable by `orvion_integration` only and refuses another tenant's lead or campaign, an unknown tenant or source code, a consent value outside the set and a second gclid; the readers `app.lead_timeline` and `app.record_offline_conversion` are SECURITY INVOKER; anonymous REST is refused (401) and does not reach the RPC (404). **Recorded positions:** the capture accepts a future `clicked_at` and a null consent from its trusted platform caller; `offline_conversions` and `app.record_offline_conversion` are their own surfaces. 0 hosted clicks. |
   ```

   e) replace the line
   ```text
   | `branch_business_hours` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `branch_business_hours` | **AUDITED** | ADVERSARIAL | `SPEC-311-a-held-document-keeps-its-finding-and-a-click-stays-in-scope` | — | `177_branch_hours_are_written_only_by_a_tenant_settings_holder_test.sql` (11 assertions; AUTH, TENANT, DOOR and PRIVILEGE declared, the rest N/A) pins the door as found: the grants are unchanged and no one deletes an hours row, not even the `owner` at `aal2`; the `owner` at `aal2` sets and edits a branch's hours; the `owner` at `aal1` is refused for want of the second factor; an employee reads the hours and cannot change them; a `branch_manager` cannot set or change even their own branch's hours; another tenant's owner sees none and cannot set them. Tests 10, 58 and 130 pass unchanged. **Swept and classified as non-defects:** writing needs MANAGE_BRANCHES (`app.guard_write_capability`) with the second factor; a branch in another tenant is refused by the foreign key; anonymous REST is refused (401). **Recorded positions:** no check keeps `day_of_week` within 0-6, `opens_at` before `closes_at`, a closed day without times or one row per branch and day; `created_at` is caller-supplied on INSERT and rewritable on UPDATE by a settings holder; a row may move between the tenant's branches; hours record no event on any door; no function, policy or view reads the hours, so none of these changes what any reader decides. No defect, so no migration; the test was added because Check 24 needs one that names the surface. 0 hosted hours. |
   ```

   f) replace the line
   ```text
   | `document_storage_findings` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `document_storage_findings` | **AUDITED** | ADVERSARIAL | `SPEC-311-a-held-document-keeps-its-finding-and-a-click-stays-in-scope` | RET-5 | `175_a_held_document_keeps_its_retention_finding_open_test.sql` (14 assertions; TENANT, DOOR, STATE and REPLAY declared, the rest N/A) proves that a candidate recorded before a hold is not claimed; that the executor's door and the resolver refuse `object_deleted`, `dismissed`, `failed` and `object_restored` on it while the hold stands, leaving the version and an open, unaged finding; that an unheld tenant's candidate is destroyed as before; and that the same finding is resolved once the hold is released. Tests 35, 49, 52, 60, 97, 116 and 135 pass unchanged. **Swept and classified as non-defects:** `authenticated` and `anon` hold no grant and the policy is `false` both ways, so an employee, the `owner` at `aal2` and another tenant are refused on read, insert and both functions; the resolver refuses an unknown or null code, an unknown finding and a second resolve, and a `failed` attempt is counted without closing the finding; `app.reconcile_document_storage` does not reopen a resolved finding; anonymous REST is refused (401) and does not reach the RPC (404). **Recorded position:** a `service_role` direct UPDATE can reopen or rewrite a finding (platform trust, as every `service_role` table). 0 hosted findings. |
   ```

   The resulting file's Git blob is 74068baae6f3cd17764f6384ec56fdaef3a4f473.

7. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, with Steps 1–6 applied and uncommitted in the main checkout, run with the project-local CLI and record, with actual counts, exits and exact SHA-256 values:
   - the SHA-256, md5 and byte counts of the migration and tests 175, 176 and 177, which must equal Consumer Closure;
   - on the local stack holding the migration: the three functions' `md5(prosrc)`, security mode and ACL, the `attribution_clicks` policy, the triggers of `branch_business_hours`, `document_storage_findings`, `attribution_clicks` and `leads` and the catalog count; tests 175, 176 and 177 alone; the probes; the thirteen mutants, with the restored shape proven equal;
   - the causal negatives: the stack before the migration, then the stack restored with it;
   - the local structural fingerprints of `scripts/parity_surface.sql`, before and after the migration;
   - the API-contract generator, whose output must equal `MASTER_API_CONTRACT.md` and differ from the baseline contract only in the one `attribution_clicks` policy row; the map generator, the scope check and `git diff --check`.

   Treat as expected at this boundary only: an undeployed Primary and the measured-state items of Consumer Closure.

   Then read a fresh Primary baseline, read-only:
   - the project URL, the full ordered ledger and the absence of the target migration;
   - the function, policy, grant and structural surfaces;
   - the triggers of the four tables, the `attribution_clicks` policy and the three functions' `md5(prosrc)`;
   - the tenant, branch, hours, document, version, finding, lead, click and event counts.

   Record the predicted delta. If any reading differs, stop.
8. **Check** that an exact-SHA Gate-2 record for the migration is in the Execution Log. It is either the owner's own, or one marked DELEGATED that names this contract, the migration's SHA-256, Primary `vrvtsxexkiiiivlkdxzp` and the owner's instructions under which it is taken. If it is absent, write it only when Step 7 passed and those instructions cover a migration that drops no table or column and deletes or rewrites no business row. Otherwise stop after Step 7 and present the Gate-2 package.
9. **Check** whether Primary `vrvtsxexkiiiivlkdxzp` lacks `20261117120000_a_held_document_keeps_its_finding_and_a_click_stays_in_scope`. If it does and Step 8 is recorded, deploy it in one sitting:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, the target's absence, the business counts, the triggers of the four tables and the `attribution_clicks` policy.
   - On an exact match, prove the transmitted text's md5 server-side, then apply only that migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row, its stored statement md5 equal to the file's, and no existing target version.

   Then read fresh: the ledger, the function surface and all ten structural surfaces; the triggers of the four tables and the `attribution_clicks` policy; the three functions' `md5(prosrc)`, security mode and ACL; and the business counts. Never contact Secondary `brplkqmbzffpxqgkkdzo`.
10. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
    - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
    - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with the client RPC figure unchanged.
    - Confirm that `supabase/tests` holds 177 files whose literal `plan(N)` values sum to 3258, then set `Suite **177 files / 3258 assertions**`. If either differs, stop.
    - In the register, replace each `` | 🛡 | **FIXED 2026-11-17 locally (SPEC-311, `20261117120000`); Primary deployment pending.** `` with `` | ✅ | **✅ FIXED 2026-11-17 (SPEC-311, `20261117120000`), DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-311; the fresh Primary ledger, functions and structure equal local.** ``, for the three rows ATTR-5, ATTR-6 and RET-5. Each span's one leading and one trailing space are delimiters, not text. Change nothing else in the register.
    - Regenerate `MASTER_API_CONTRACT.md` with the canonical generator, which must leave it equal to the verified contract of Step 7 (the one `attribution_clicks` policy row moved from the baseline), and regenerate `ai-map.json` and `repository-index.md` (stored LF) with the canonical generator.
    - Set the Runtime Checkpoint to DONE, append the Execution Log, and commit the implementation once. The pre-commit Gate must admit it.

    If Primary is unproven, stop.
11. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
    - Run canonical `-Finish` through `scripts/run_timed.ps1`, watched by `scripts/watch_run.ps1`, and require `LOCAL_CERTIFY: READY`.
    - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, make the Complete commit:
      - transition to Complete and tick the Acceptance Criteria and the Review Gate;
      - clear `Active Change Request` and set `Last Completed` from Notes;
      - leave `Next capability` and `Current Module` unchanged;
      - regenerate `ai-map.json` and `repository-index.md` LF.
    - Bind the exact candidate with `-Gate -BindCandidate`. Publication and promotion follow the native release path separately.

## Acceptance Criteria

- [ ] The migration is the frozen bytes; `check: blob supabase/migrations/20261117120000_a_held_document_keeps_its_finding_and_a_click_stays_in_scope.sql cac36174e8c9bbd4423192815da9c65611dd03e7`
- [ ] Test 175 is the frozen bytes; `check: blob supabase/tests/175_a_held_document_keeps_its_retention_finding_open_test.sql 11afba06cdc320d6353b5cd88a72d1cb64d65732`
- [ ] Test 176 is the frozen bytes; `check: blob supabase/tests/176_a_click_is_read_through_its_lead_and_anchors_only_its_lead_test.sql 1a091b7848ead9adc544c1ab92ec8dd89af29284`
- [ ] Test 177 is the frozen bytes; `check: blob supabase/tests/177_branch_hours_are_written_only_by_a_tenant_settings_holder_test.sql b58da8e600750ad93e1544b28426a59a2d977e95`
- [ ] The disposition record carries the three surfaces AUDITED / ADVERSARIAL and coverage 66 of 78; `check: blob reports/master/MASTER_SURFACE_DISPOSITION.md 74068baae6f3cd17764f6384ec56fdaef3a4f473`
- [ ] The three register rows are fixed and deployed; `check: has reports/master/MASTER_GAP_REGISTER.md "DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-311"`
- [ ] The manifest suite figure equals the files; `check: has _ORVION_CANONICAL/manifest.md "Suite **177 files / 3258 assertions**"`
- [ ] Native evaluator remains exact; `check: same scripts/check_agent_continuity.ps1 @ad3a7d4db513834c2bfab0b15b1b49a74eb12590`
- [ ] The storage executor's origin migration remains exact; `check: same supabase/migrations/202607055300_storage_executor_contract.sql @ad3a7d4db513834c2bfab0b15b1b49a74eb12590`
- [ ] The smoke catalog count remains exact; `check: same scripts/verify_database.sql @ad3a7d4db513834c2bfab0b15b1b49a74eb12590`
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the one authorized migration, with at most one guarded ledger rename and no business-data write, after a recorded Step 7 readiness gate and Step 8 Gate-2 record. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] The thirteen mutants are each killed with installation proven and the restored shape read, and the two causal negatives and the probes, before and after, are recorded.

## Execution Log

None.

## Verification Notes

None.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

After actual native Finish and truthful Review, synchronize only this contract and the declared manifest/discovery paths to Complete. Set `Last Completed: **SPEC-311: Batch 6 Slice 55 — a held document keeps its retention finding open; an attribution click is read through its lead's scope and anchors only its own lead (RET-5, ATTR-5, ATTR-6); branch_business_hours audited, deployed to Primary; native verification and Review complete. Publication/promotion remain separately governed.**` and regenerate discovery. `Next capability` and `Current Module` stay unchanged: the selector names the next slice. Candidate binding follows Complete and is never a pre-Complete criterion.

Exact baseline ad3a7d4db513834c2bfab0b15b1b49a74eb12590 and source anchors:

| Path | Baseline Git blob |
| --- | --- |
| `reports/master/MASTER_GAP_REGISTER.md` | `9908f95666013e3071ab469fc2eb314b947c8423` |
| `reports/master/MASTER_SURFACE_DISPOSITION.md` | `f538696bf92b7855d69e349c6f12c0383fc54cb2` |

Selection sources: native AGENTS.md, CR_LIFECYCLE.md and ENGINEERING_METHOD.md; SPEC-119, SPEC-232, SPEC-305 and SPEC-306 at ad3a7d4db513834c2bfab0b15b1b49a74eb12590; the owner's instructions of 2026-11-08, 2026-11-16 and 2026-11-17 (recorded outside this repository). This is the one Draft for these surfaces, finalized after the adversarial review and the evidence refresh that its Draft Assurance records. Correctness remains native and independent.
