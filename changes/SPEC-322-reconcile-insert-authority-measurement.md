# Change Request — SPEC-322

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Reconcile PAX-4 and the lead-interactions surface boundary using the existing effective INSERT authority checks. Remove the two duplicate policy-site assertions that misclassified campaign daily metrics.

## Business Reason

The released CRM Action Registry at d4bed23db3c03ed4c91508fb595a0ca10515f0da requires the remaining PAX-4 writer rationale for lead interactions and campaign metrics. The local 274-migration catalog shows the campaign metrics write predicate on a FOR ALL policy and the lead-interactions handler authority trigger enabled. Test 106 assertions 15 and 16 only examined INSERT or UPDATE policy rows and called the remaining historical sample ungoverned. Test 67 SEC-1b already measures INSERT grants together with applicable INSERT and ALL policies and INSERT trigger authority across the live table population. Its two identity-only members are governed by Canon 34 and the existing SPEC-259 and Test 106 evidence. Test 101 pins campaign metrics policy and Test 108 pins lead-interaction writer authority and the separate open LI-3 behavior.

This changes verification and records. It does not change database write authority. The replay derives 10 due at B6-EXIT and leaves the surface disposition unchanged. The authority measurement answer for PAX-4 does not resolve STEPUP-1 or the dependency on the existing side-effect decision for LI-3.

## Risks

Preserve Test 106 assertions 1 through 14 and all stronger owning tests. Maintain the manifest suite size as a planned assertion count until independently executed. Keep LI-3 and the lead-interactions surface at ENABLE-CRM and AUTH-1 at its existing trigger. Preserve STEPUP-1, entry and archive findings and all eleven exit-criterion statuses. The adjustment audit-event discrepancy is separate and must be evaluated against Canon 27 and the historical Class C deferral before any repair.

## Supersedes / Depends On

Builds on the certified SPEC-321 revision. Uses Canon 34, SPEC-259, and existing Tests 67, 101, 106, 108 and 151. Historical contracts, proofs and previous decisions remain immutable.

## Write Scope

- `changes/SPEC-322-reconcile-insert-authority-measurement.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `supabase/tests/106_otp_challenge_subject_authority_test.sql`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `scripts/readiness_population.ps1`
- `scripts/check_repository_consistency.ps1`
- `supabase/tests/67_care_capability_and_message_integrity_test.sql`
- `supabase/tests/101_marketing_metrics_and_fx_adjustment_surface_test.sql`
- `supabase/tests/108_lead_interaction_log_integrity_test.sql`
- `supabase/tests/151_a_totp_enrollment_record_decides_nothing_test.sql`
- `supabase/config.toml`

Product code, schema and migration work, Supabase production writes, Founder ORVION, and approval policy changes are out of scope.

## Required Reading

- `CR_LIFECYCLE.md` sections 4–9 and `ENGINEERING_METHOD.md` local database verification.
- `reports/master/MASTER_GAP_REGISTER.md` PAX-4, OTP-1, OTP-2, LI-3 and STEPUP-1.
- `reports/master/MASTER_EXECUTION_PLAN.md` Action Registry and EC-2.
- `_ORVION_CANONICAL/34_authentication_and_identity_principles.md` identity authority.
- `supabase/tests/67_care_capability_and_message_integrity_test.sql` SEC-1b and the affected Test 106 block. Test 101 pins the campaign write predicate and Test 108 pins lead-interaction authorization.

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- supabase-local

## Additional Verification

- `pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: Reuse Test 67 SEC-1b as the INSERT-path measurement and preserve Test 106's independent authentication coverage.

Pass 2 Adversarial Review: Test 106 used INSERT and UPDATE policy rows only. The exact Test 67 SELECT returned two ownership surfaces. Omitting ALL in an in-memory read-only variant made campaign_daily_metrics reappear in the uncovered set. Removing the duplicate avoids maintaining a contradictory policy-location count. Test 101 independently pins campaign policy and Test 108 verifies actor-bound authority while reserving LI-3. Do not bundle the separate exchange adjustment audit-event and STEPUP-1 assessments.

Pass 3 Evidence Refresh: 2026-11-20. Verified the released SPEC-321 evidence and unchanged certified migration tree. Re-ran the extracted Test 67 catalog assertion and its omission variant in the local read-only transaction. Isolated registry replay yields 10 due. Repository consistency passes after synchronizing the real 182-file, 3379-planned-assertion count. Full local execution is required at Original Finish.

Selected Version: One test-and-record candidate retiring only the redundant sample assertions, closing proven PAX-4 measurement work, and returning lead_interactions to its existing LI-3 trigger.

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| PAX-4 enforcement measurement | Test 67 SEC-1b and Tests 101, 108, 151 | VERIFY | Preserve exact blobs. Live Test 67 query and negative measurement probe cover the retired sample claim. |
| OTP protocol regression | Test 106 | WRITE | Keep assertions 1 through 14 byte-identical. Remove only duplicate policy-site claims and update the test plan and header. |
| PAX-4 and LI-3 | Gap Register, Action Registry, Check 29 | WRITE | Close the PAX-4 measurement. Preserve LI-3, its existing decision dependency and the open lead-interactions disposition. |
| Surface coverage, class obligations and EC status | Master Surface Disposition, registry replay and exit criteria | VERIFY | Preserve source bytes and all deadlines outside the named members. |
| Suite count and lifecycle | Manifest, discovery and repository consistency | WRITE | Decrement the suite plan by the two retired assertions. Retain 182 files and regenerate native projections. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Actual catalog predicates and replayed source anchors match | BEFORE_IMPLEMENTATION | NONE | NONE | NONE |
| Suite plan and manifest agree | BEFORE_COMPLETION | NONE | NONE | 5 |
| Required DATABASE and REPOSITORY verification | BEFORE_COMPLETION | NONE | NONE | NONE |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: Yes. Test 67 SEC-1b owns the effective INSERT-path classification. Tests 101, 108 and 151 retain the member proof.

Existing Mechanism: Existing pgTAP suites and native DATABASE and REPOSITORY verification.

Added Property: No new permanent control. Remove a duplicate stale measurement while keeping the stronger live-table check and all OTP-specific assertions.

Causal Negative: The old Test 106 policy predicate omitted FOR ALL and labelled campaign metrics as outside the write-policy check. The actual catalog proves the opposite.

Positive Test Design: Existing Test 67 must return exactly totp_enrollments and trusted_devices. The verified Test 106 OTP assertions continue to run.

Negative Test Design: A read-only SELECT variant that omits FOR ALL changes the Test 67 result to include campaign_daily_metrics.

Non-Empty Population Obligation: Require the exact two Test 67 ownership members and retain Tests 101 and 108's existing positive controls.

Mutation Obligation: Replay the read-only omission and confirm the Test 67 assertion would fail. Use the existing isolated result when the source and catalog identities match.

Post-Implementation Proof Obligation: Record the native DATABASE readiness and Finish results and the unchanged owning-test blobs. Independently recheck Check 29 and the exact record scope.

## Implementation Steps

1. Check whether `supabase/tests/106_otp_challenge_subject_authority_test.sql` contains `INSERT authorization coverage is owned by Test 67`; if so record Already Applied when its Git blob is 02adabd5182f9515a5c1ff17bbaf6431fb083519, and otherwise stop and report. Otherwise make exactly these 3 edits (retire the redundant measurement assertions only), each matched once, and change nothing else:

   a) replace the lines
   ```text
   -- 15-16 are the PAX-4 correction, made executable. `202607061400` recorded that 20 tables "have no
   --       trigger that calls app.authorize or app.has_permission at all" and read that as 20
   --       ungoverned writes. Re-measured: 15 of the 20 carry the capability check inside the RLS
   --       POLICY instead of a trigger, so the count was of ENFORCEMENT SITES OF ONE KIND and the
   --       inference drawn from it was about GOVERNANCE. These two assertions exist so the corrected
   --       number cannot quietly drift back to the proxy: if a future change moves a capability check
   --       from a policy into a trigger, or removes one, the numbers move and this file fails.
   ```
   with
   ```text
   -- INSERT authorization coverage is owned by Test 67 (SEC-1b). Test 106 keeps the independent OTP assertions.

   ```

   b) replace the line
   ```text
   select plan(16);
   ```
   with
   ```text
   select plan(14);
   ```

   c) replace the lines
   ```text

   -- =============================================================================================
   -- 15-16. THE PAX-4 CORRECTION, MADE EXECUTABLE.
   -- =============================================================================================
   select is(
     (with named(t) as (values
        ('branches'),('catalog_values'),('chart_of_accounts'),('departments'),('exchange_rates'),
        ('journal_entries'),('journal_entry_lines'),('lead_interactions'),('subscriptions'),('tenants'),
        ('users'),('user_branch_assignments'),('user_permission_grants'),('otp_challenges'),
        ('totp_enrollments'),('trusted_devices'),('campaign_daily_metrics'),('document_retention_policies'),
        ('exchange_rate_adjustments'),('subscription_payment_proofs'))
      select count(*)::int from named n
       where coalesce((select bool_or(coalesce(pg_get_expr(p.polqual, p.polrelid),'') ||
                                      coalesce(pg_get_expr(p.polwithcheck, p.polrelid),'') ~* '(has_permission|authorize)')
                         from pg_policy p
                        where p.polrelid = ('public.' || n.t)::regclass and p.polcmd in ('a','w')), false)),
     15,
     'PAX-4 CORRECTED: 15 of the 20 tables it counted as having "no capability trigger" carry the capability check inside the RLS POLICY -- the count measured enforcement sites of one kind and was read as governance');

   select is(
     (with named(t) as (values
        ('branches'),('catalog_values'),('chart_of_accounts'),('departments'),('exchange_rates'),
        ('journal_entries'),('journal_entry_lines'),('lead_interactions'),('subscriptions'),('tenants'),
        ('users'),('user_branch_assignments'),('user_permission_grants'),('otp_challenges'),
        ('totp_enrollments'),('trusted_devices'),('campaign_daily_metrics'),('document_retention_policies'),
        ('exchange_rate_adjustments'),('subscription_payment_proofs'))
      select coalesce(string_agg(n.t, ',' order by n.t), '') from named n
       where not coalesce((select bool_or(coalesce(pg_get_expr(p.polqual, p.polrelid),'') ||
                                          coalesce(pg_get_expr(p.polwithcheck, p.polrelid),'') ~* '(has_permission|authorize)')
                             from pg_policy p
                            where p.polrelid = ('public.' || n.t)::regclass and p.polcmd in ('a','w')), false)),
     'campaign_daily_metrics,lead_interactions,otp_challenges,totp_enrollments,trusted_devices',
     '...and PAX-4''s genuinely uncovered set is these FIVE, each already dispositioned or registered -- named rather than counted, so a new member cannot hide inside a number that still reads 5');

   ```
   with
   ```text

   ```

   The resulting file's Git blob is 02adabd5182f9515a5c1ff17bbaf6431fb083519.

2. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `authorization measurement reconciled`; if so record Already Applied when its Git blob is 21ace69e0132278a4ad89950a83ff4af61c92e56, and otherwise stop and report. Otherwise make exactly this one edit (reconcile PAX-4 using the owning evidence), each matched once, and change nothing else:

   a) replace the line
   ```text
   | PAX-4 | **The "twenty ungoverned tables" count measured trigger sites, not governance — the real number is five** | security / authorization · measurement | Medium | O | 6 | — | 📋 | **OPEN — engineering, but SMALLER AND DIFFERENT THAN RECORDED. The count was never wrong; the inference drawn from it was.** As recorded in slice 4: of the tables `authenticated` may INSERT, **20 have no trigger calling `app.authorize` or `app.has_permission` on INSERT**. Slice 6 re-measured what that implies and found **15 of the 20 carry the capability check inside the RLS POLICY instead of a trigger** — `user_permission_grants` is the clearest case, with three triggers (`derive_created_by`, `moddatetime`, `emit_permission_change`) of which **not one authorizes**, while `scope_insert` and `scope_update` both require `app.has_permission('MANAGE_PERMISSIONS')`. PAX-4 counted **enforcement sites of one kind and reported it as governance**: the same MEAS-1 shape as GUARD-CRLF-1 and Check 12, this time in a register row rather than a guard. **The genuinely uncovered set is FIVE, and every one already has a disposition or a registered reason:** `otp_challenges` (**CLOSED by OTP-1**, slice 6), `totp_enrollments` (**OTP-2**, open decision), `trusted_devices` (canon 34 — ownership IS the model, and `58_...` tests that boundary rather than asserting it), `lead_interactions` (already registered BLOCKED/business in `202607056100`) and `campaign_daily_metrics` (already `AUDITED`, slice 1). **The old row also carried a claim slice 6 DISPROVED and which had reached the manifest:** that `otp_challenges` "is a pre-authentication surface and a capability check there would be a category error". The category-error half is right; the pre-authentication half is false — `anon` holds no grant and matches no policy on that table, so an unauthenticated caller could never reach it, and the surface is INTRA-authentication (canon 34 § 7 makes OTP a second factor, presented at `aal1`). **Stays OPEN** because the five-table question is real, and PAX-4 keeps its ID rather than being closed and reopened so the correction stays attached to what it corrects. **Trigger:** each remaining table's own Batch 6 slice. Ceiling pinned at `<= 20` by `10_grant_model_test` assertion 7 and the membership now NAMED by `67_...` assertion 7 and `106_...` assertions 15-16 — a bare count cannot see one table leaving as another joins **2026-11-19 (CRM exit reconciliation):** OTP-2 is resolved by derivation and SPEC-259 shows that TOTP enrollments do not govern MFA. AUTH-1 retirement is trigger-bound. Test 106 assertions 15–16 prove enforcement location. Class closure still requires each remaining authority rationale. | — | session-2026-09-07-batch6-slice4-booking-item-passengers | 09-07 | 11-19 |
   ```
   with
   ```text
   | PAX-4 | **The "twenty ungoverned tables" count measured trigger sites, not governance — the real number is five** | security / authorization · measurement | Medium | O | 6 | — | 📋 | **FIXED — authorization measurement reconciled.** Test 106 assertions 15–16 used a historical policy-site sample and excluded FOR ALL policies. The actual INSERT-path proof remains Test 67 SEC-1b. Test 101 establishes the campaign metric write policy, and Test 108 establishes the assigned-handler or permission-plus-MFA guard for lead interactions. OTP-1 removed member writes. The two remaining no-capability surfaces use Canon 34 ownership, with SPEC-259 proving TOTP records do not decide MFA and Test 106 preserving trusted-device coverage. AUTH-1, LI-3 and STEPUP-1 keep their own boundaries. Historical evidence follows: **OPEN — engineering, but SMALLER AND DIFFERENT THAN RECORDED. The count was never wrong; the inference drawn from it was.** As recorded in slice 4: of the tables `authenticated` may INSERT, **20 have no trigger calling `app.authorize` or `app.has_permission` on INSERT**. Slice 6 re-measured what that implies and found **15 of the 20 carry the capability check inside the RLS POLICY instead of a trigger** — `user_permission_grants` is the clearest case, with three triggers (`derive_created_by`, `moddatetime`, `emit_permission_change`) of which **not one authorizes**, while `scope_insert` and `scope_update` both require `app.has_permission('MANAGE_PERMISSIONS')`. PAX-4 counted **enforcement sites of one kind and reported it as governance**: the same MEAS-1 shape as GUARD-CRLF-1 and Check 12, this time in a register row rather than a guard. **The genuinely uncovered set is FIVE, and every one already has a disposition or a registered reason:** `otp_challenges` (**CLOSED by OTP-1**, slice 6), `totp_enrollments` (**OTP-2**, open decision), `trusted_devices` (canon 34 — ownership IS the model, and `58_...` tests that boundary rather than asserting it), `lead_interactions` (already registered BLOCKED/business in `202607056100`) and `campaign_daily_metrics` (already `AUDITED`, slice 1). **The old row also carried a claim slice 6 DISPROVED and which had reached the manifest:** that `otp_challenges` "is a pre-authentication surface and a capability check there would be a category error". The category-error half is right; the pre-authentication half is false — `anon` holds no grant and matches no policy on that table, so an unauthenticated caller could never reach it, and the surface is INTRA-authentication (canon 34 § 7 makes OTP a second factor, presented at `aal1`). **Stays OPEN** because the five-table question is real, and PAX-4 keeps its ID rather than being closed and reopened so the correction stays attached to what it corrects. **Trigger:** each remaining table's own Batch 6 slice. Ceiling pinned at `<= 20` by `10_grant_model_test` assertion 7 and the membership now NAMED by `67_...` assertion 7 and `106_...` assertions 15-16 — a bare count cannot see one table leaving as another joins **2026-11-19 (CRM exit reconciliation):** OTP-2 is resolved by derivation and SPEC-259 shows that TOTP enrollments do not govern MFA. AUTH-1 retirement is trigger-bound. Test 106 assertions 15–16 prove enforcement location. Class closure still requires each remaining authority rationale. | — | session-2026-09-07-batch6-slice4-booking-item-passengers | 09-07 | 11-20 |
   ```

   The resulting file's Git blob is 21ace69e0132278a4ad89950a83ff4af61c92e56.

3. Check whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `Fixed by the insert-authority reconciliation`; if so record Already Applied when its Git blob is 5c33d781bb9b41f3a908036aca95036b663040eb, and otherwise stop and report. Otherwise make exactly these 3 edits (retain the individual side-effect and ownership boundaries), each matched once, and change nothing else:

   a) replace the line
   ```text
   | PAX-4 | VERIFIED DEFECT | engineering | `B6-EXIT` | EC-2 and its five named members | UNPROVEN as a defect class. Test 106 assertions 15–16 pin enforcement locations. OTP-1, OTP-2, Canon 34 and surface evidence explain individual cases. Verify the remaining writer rationale for lead interactions and campaign metrics before assigning any repair. |
   ```
   with
   ```text
   | PAX-4 | VERIFIED DEFECT | engineering | `B6-EXIT` | EC-2 and the INSERT-path authority | Fixed by the insert-authority reconciliation. Test 67 SEC-1b owns the live measurement, Test 101 pins campaign metrics policy, and Test 108 pins lead interaction authority. Test 106 retains its OTP assertions. Canon 34 and SPEC-259 explain the ownership-only cases. STEPUP-1 and AUTH-1 remain independent. |
   ```

   b) replace the line
   ```text
   | `lead_interactions` | SURFACE | engineering | `B6-EXIT` | PAX-4 and LI-3 | Test 108 pins the LI-1/LI-2 repairs and the LI-3 behavior. Verify the actor-bound write rationale. Any lifecycle repair depends on the existing FIN-9/FIN-11 side-effect authority before CRM enablement. |
   ```
   with
   ```text
   | `lead_interactions` | SURFACE | engineering | `ENABLE-CRM` | LI-3 and the existing FIN-9/FIN-11 side-effect decision | Test 108 proves the actor-bound write authority, closure of LI-1/LI-2, and the existing LI-3 behavior. PAX-4's measurement is reconciled. Preserve AUDITED-OPEN until the lifecycle side-effect authority and LI-3 evidence are resolved. |
   ```

   c) replace the line
   ```text
   | `otp_challenges`, `totp_enrollments` | SURFACE | engineering | `OWN-TRIGGER` | AUTH-1 | OTP-1's repair and OTP-2's derivation are recorded. Test 106 and SPEC-259/test 151 cover the present boundary. Retire before the first client-facing authentication build or first reference. PAX-4 class assessment stays due at exit. |
   ```
   with
   ```text
   | `otp_challenges`, `totp_enrollments` | SURFACE | engineering | `OWN-TRIGGER` | AUTH-1 | OTP-1's repair and OTP-2's derivation are recorded. Test 106 and SPEC-259/test 151 cover the present boundary. Retire before the first client-facing authentication build or first reference. |
   ```

   The resulting file's Git blob is 5c33d781bb9b41f3a908036aca95036b663040eb.

4. Check whether `_ORVION_CANONICAL/manifest.md` contains `182 files / 3379 assertions`; if so record Already Applied when its Git blob is f7bd24e4aab0bfa1081db77b929ed645fbc70df4, and otherwise stop and report. Otherwise make exactly this one edit (synchronize the planned pgTAP assertion count), each matched once, and change nothing else:

   a) replace the line
   ```text
   Live state: **Repository, local stack and Platinum Primary `vrvtsxexkiiiivlkdxzp` at 274 migrations** (latest `20261120122927`), ledger `67a6f9f8b5454c75d09b62a8f748c20d`. full-function-surface hash `c4ace99188f8408aacfca26af946371b` (352 functions), structural-surface hash `09d7482ae39d8b62d64887c1a351d8dd` (3,189 objects). All ten surfaces match. Ledger read FROM Primary 2026-11-20. **80 client RPCs**. Suite **182 files / 3381 assertions**.
   ```
   with
   ```text
   Live state: **Repository, local stack and Platinum Primary `vrvtsxexkiiiivlkdxzp` at 274 migrations** (latest `20261120122927`), ledger `67a6f9f8b5454c75d09b62a8f748c20d`. full-function-surface hash `c4ace99188f8408aacfca26af946371b` (352 functions), structural-surface hash `09d7482ae39d8b62d64887c1a351d8dd` (3,189 objects). All ten surfaces match. Ledger read FROM Primary 2026-11-20. **80 client RPCs**. Suite **182 files / 3379 assertions**.
   ```

   The resulting file's Git blob is f7bd24e4aab0bfa1081db77b929ed645fbc70df4.

5. Verify the four exact scoped payloads, Test 106 assertions 1 through 14, and the unchanged owning suites and migrations. Re-derive the 10 B6-EXIT items, completed PAX-4, and LI-3 and lead_interactions NOT DUE at ENABLE-CRM. Recheck AUTH-1, STEPUP-1, all dispositions and all exit criteria. Update native discovery and run required local DATABASE readiness before the Original Finish. Follow the timed and watched native Finish, independent Review and Complete. Use `Last Completed: **SPEC-322: Reconciled PAX-4 INSERT authority evidence.**`. No production deployment applies. Release retains its exact candidate gates.

## Acceptance Criteria

- [x] The scoped retire the redundant measurement assertions only payload equals the isolated edit. `check: blob supabase/tests/106_otp_challenge_subject_authority_test.sql 02adabd5182f9515a5c1ff17bbaf6431fb083519`
- [x] The scoped reconcile PAX-4 using the owning evidence payload equals the isolated edit. `check: blob reports/master/MASTER_GAP_REGISTER.md 21ace69e0132278a4ad89950a83ff4af61c92e56`
- [x] The scoped retain the individual side-effect and ownership boundaries payload equals the isolated edit. `check: blob reports/master/MASTER_EXECUTION_PLAN.md 5c33d781bb9b41f3a908036aca95036b663040eb`
- [x] Test 67 SEC-1b remains the effective INSERT-path measurement. The positive and omission checks prove its population and Test 106 assertions 1 through 14 stay identical.
- [x] Test 101 preserves campaign policy coverage and Test 108 preserves actor-bound writer coverage and the recorded LI-3 behavior.
- [x] Native Check 29 derives ten obligations due at B6-EXIT, PAX-4 completed, and lead_interactions and LI-3 NOT DUE at ENABLE-CRM. AUTH-1, STEPUP-1 and every unrelated obligation remain at their existing boundaries.
- [x] Local DATABASE and REPOSITORY evidence is certified for this Original, including the named HTTP suite. The suite manifest reports 182 files and 3379 assertions.
- [x] The disposition and registry evaluator remain byte-identical to the baseline. `check: same reports/master/MASTER_SURFACE_DISPOSITION.md @d4bed23db3c03ed4c91508fb595a0ca10515f0da` `check: same scripts/readiness_population.ps1 @d4bed23db3c03ed4c91508fb595a0ca10515f0da`
- [x] Test 67, Test 101, Test 108 and Test 151 remain byte-identical to the baseline and the contract introduces no migration.

## Execution Log

None.


### 2026-11-20 — Implementation checkpoint (governed automation)

Outcome: Complete (implementation steps; final verification pending)

- Step 1 Applied: native recorded Gate 1 evidence names this exact Draft's SHA-256; the baseline HEAD was d4bed23db3c03ed4c91508fb595a0ca10515f0da and every source anchor matched there; Draft allocated as 6156436 and approved as d1d24c3 with APPROVAL_EVIDENCE: PASS.
- Step 2 Applied: `supabase/tests/106_otp_challenge_subject_authority_test.sql` edited exactly as the step states; blob 02adabd5182f9515a5c1ff17bbaf6431fb083519 (3 insertions, 41 deletions).
- Step 3 Applied: `reports/master/MASTER_GAP_REGISTER.md` edited exactly as the step states; blob 21ace69e0132278a4ad89950a83ff4af61c92e56 (1 insertions, 1 deletions).
- Step 4 Applied: `reports/master/MASTER_EXECUTION_PLAN.md` edited exactly as the step states; blob 5c33d781bb9b41f3a908036aca95036b663040eb (3 insertions, 3 deletions).
- Step 5 Applied: `_ORVION_CANONICAL/manifest.md` edited exactly as the step states; blob f7bd24e4aab0bfa1081db77b929ed645fbc70df4 (1 insertions, 1 deletions).
- Step 6 Applied: generator rerun, `generate-ai-map.ps1 -Check` exit 0, the staged change names only Write Scope paths. Every edit was applied literally from this contract's steps and its Git blob checked before commit. Fresh timed and watched Finish, independent Review, Complete and candidate binding remain. No production write applies to this contract. Owner publication and promotion retain their native release authority.

## Verification Notes

None.


### 2026-11-20 — Gate 1 approval recorded

The owner approved the exact SPEC-322 Gate 1 request in the current session. The approval is bound to the single presented Draft SHA-256 FB7EC33BD6AC09164FA26B57D45177B154D2DF2AA14962B644C05CD37170B8A9. Verbatim approval section retained in private Workbench evidence OWNER-ORIGINAL-APPROVAL.txt with SHA-256 D410CD413FFFB70594A0BB08D8C61A417396FD95DCFB218F1EF7C21062222385. The scope is the frozen CRM record-only candidate and the native Original lifecycle. Immediately before allocation the hash, the Draft blob c1a2ebe860877e7765a2d917c8a069254307ac83, all 4 source anchors, the baseline HEAD d4bed23db3c03ed4c91508fb595a0ca10515f0da against refreshed origin/main d4bed23db3c03ed4c91508fb595a0ca10515f0da and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 6156436. No implementation performed before this transition. No production write applies to this contract. Owner publication and promotion retain their native release authority.


### 2026-11-20 — Independent Original Review

Verdict: Confirmed Complete

Findings: Verified committed Original de5b426c30176e1422f0bc59a3cb0055c467eb89 against baseline d4bed23db3c03ed4c91508fb595a0ca10515f0da. Only the contract, Test 106, the Gap Register, the Execution Plan, the active manifest and its generated map changed. Test 106 equals 02adabd5182f9515a5c1ff17bbaf6431fb083519, the Gap Register 21ace69e0132278a4ad89950a83ff4af61c92e56 and the Execution Plan 5c33d781bb9b41f3a908036aca95036b663040eb. Test 106 removes only assertions 15 and 16 and plans 14; assertions 1 through 14 and the fixture are unchanged. Tests 67, 101, 108 and 151, the Surface Disposition, readiness_population, the consistency evaluator, check_agent_continuity, Migration CI and config.toml are byte-identical to baseline, and no migration changed. The native committed registry matches the complete isolated replay in every row. Against the released SPEC-321 population exactly two rows moved: PAX-4 to COMPLETED and lead_interactions to NOT DUE at ENABLE-CRM; LI-3 stays NOT DUE at ENABLE-CRM, STEPUP-1 stays DUE NOW at B6-EXIT and every other obligation keeps its state and boundary. Check 29 derives ten due at B6-EXIT. The suite holds 182 files and 3379 planned assertions, counted independently from the committed tests. The native timed and watched Finish ran DATABASE (db reset, test db, verify_api_end_to_end, verify_database, parity evidence) and REPOSITORY and returned LOCAL_CERTIFY READY, END exit 0, with own receipt SHA-256 c7150924906fdd01868a786148ce733b1cbae394a6c3311ef52befff3ee0695a at finishHead de5b426.

Recommendation: Complete and bind the exact record-only Original. No deployment applies.


Local original native verification and truthful Review complete. Preserve this root's receipt c7150924906fdd01868a786148ce733b1cbae394a6c3311ef52befff3ee0695a and selected bytes. Candidate binding follows Complete; publication/promotion remain separately governed.

## Review Gate

- [x] Every change matches the accepted implementation steps.
- [x] All changed paths are within Write Scope.
- [x] All criteria are verified against the exact live Original and fresh native evidence.
- [x] Native Finish and independent Review are present.

## Notes

Baseline: d4bed23db3c03ed4c91508fb595a0ca10515f0da.

Workstream evidence: released SPEC-321, local catalog readback, Test 67 live projection and omission probe, isolated registry and repository replay. Placement follows the existing native contract packet.

| Path | Baseline Git blob |
| --- | --- |
| `supabase/tests/106_otp_challenge_subject_authority_test.sql` | `c2a36860a5d19be926b3e7a30a42d55b7a31d0ff` |
| `reports/master/MASTER_GAP_REGISTER.md` | `c7ff8f23e3dc9f704dd6abd97c3576e71e0e3dff` |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `3347d75afa11a93738478c161eb6382d0ba2c269` |
| `_ORVION_CANONICAL/manifest.md` | `e0035646481ba6028c165e8ab565b114d659ac93` |
