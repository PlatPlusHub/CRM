# Change Request — SPEC-222

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make a direct authenticated INSERT or UPDATE of `public.marketing_campaigns` cost the same authority as the sanctioned campaign RPCs: `MANAGE_MARKETING_CAMPAIGN` charged through `app.authorize`, which is permission AND step-up.

## Business Reason

Batch 6 Slice 21 selected `marketing_campaigns` live at Exposure 10, coverage 26; `passengers` was runner-up at 10/70. `MANAGE_MARKETING_CAMPAIGN` is held only by `owner` and `ceo`, and `app.requires_mfa` lists both, so every holder is step-up-bound. `app.create_marketing_campaign` and `app.advance_marketing_campaign` charge `app.authorize`, but the table door is governed only by the `scope_isolation` RLS policy, whose WITH CHECK calls `app.has_permission` (permission only). In rolled-back probes an `owner` at `aal1` was refused `42501 multi-factor authentication required for this role` by the RPC and, in the same transaction, directly INSERTed a campaign and rewrote an existing campaign's `platform_code`, `external_campaign_id` and `campaign_name`. Consequence measured: an already-attributed click then reported under the rewritten identity (`meta_ads/M-1/Hijacked`), and an `aal1` squat of platform id `G-777` (born `ended`) made the genuine registration through the RPC at `aal2` fail `23505 campaign G-777 is already recorded`. This is the USR-2 step-up-parity shape on a different surface; it is not a new permission or policy.

## Risks

- `app.guard_write_capability` is shared by 27 tables; the replacement must add exactly one INSERT-map arm and change nothing else.
- A refusal could come from `app.enforce_status_transition` (same MFA text on status moves) or RLS (also 42501); tests must refuse only non-status changes and INSERTs, and pin the exact message.
- Primary deployment changes production function behaviour and adds one trigger; it requires separate exact-byte owner authorization after local proof.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-222-marketing-campaign-step-up-parity.md`
- `supabase/migrations/20260926120000_marketing_campaign_step_up_parity.sql`
- `supabase/tests/127_marketing_campaign_step_up_parity_test.sql`
- `supabase/tests/58_write_grants_and_config_capability_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607057000_capability_on_the_insert_path_and_a_message_that_cannot_be_forged.sql`
- `supabase/migrations/20260909132000_the_manifest_freezes_when_the_ticket_is_issued.sql`
- `supabase/migrations/202607058200_a_conversion_value_is_money_that_leaves_the_building.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/57_write_capability_map_test.sql`
- `supabase/tests/78_marketing_conversion_integrity_test.sql`
- `supabase/tests/85_write_capability_on_update_test.sql`
- `scripts/verify_lifecycle_branches.ps1`
- `scripts/verify_database.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/34_authentication_and_identity_principles.md` §7 (role-driven factor requirement); `_ORVION_CANONICAL/28_permissions_matrix.md` (`MANAGE_MARKETING_CAMPAIGN`); `_ORVION_CANONICAL/26_state_machines.md` (Marketing Campaign); `_ORVION_CANONICAL/31_schema_draft.md` (`marketing_campaigns`)
- Current local `app.guard_write_capability`, `app.authorize`, `app.has_permission`, `app.mfa_satisfied`, `app.requires_mfa`, `app.enforce_status_transition`, `app.create_marketing_campaign`, `app.advance_marketing_campaign`; `supabase/tests/58_write_grants_and_config_capability_test.sql` assertions 25–26
- `reports/master/MASTER_SURFACE_DISPOSITION.md` (`marketing_campaigns`); `reports/master/MASTER_GAP_REGISTER.md` (CAMP-1, CAMP-2, ENTRY-1, SEC-1b, USR-2, USR-3)

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
| Direct authenticated INSERT and UPDATE of `marketing_campaigns` charge `app.authorize('MANAGE_MARKETING_CAMPAIGN')` | `app.create_marketing_campaign`; `app.advance_marketing_campaign`; PostgREST table door | VERIFY | Both RPCs already call `app.authorize` before writing, so their callers are already `aal2`. Rolled-back prototype: owner `aal1` direct INSERT and non-status UPDATE refused `42501 multi-factor authentication required for this role`; owner `aal2` RPC create, RPC advance draft→active and direct UPDATE succeeded; `employee` (no capability) refused `permission denied: one of MANAGE_MARKETING_CAMPAIGN is required to write marketing_campaigns`. |
| Campaign identity (`platform_code`, `external_campaign_id`, `campaign_name`) and existence | `public.attribution_clicks`; `public.offline_conversions`; `public.campaign_daily_metrics`; `app.capture_attribution_click`; `app.record_offline_conversion` | VERIFY | Readers join or validate by campaign id only; none is changed. Measured before repair: an `aal1` re-point made an attributed click report `meta_ads/M-1/Hijacked`, and an `aal1` squat of `G-777` made the RPC refuse the genuine registration `23505`. After repair both writes require `aal2`. |
| The shared guard's other 27 attachments | every table carrying `*_guard_write_capability` | VERIFY | Prototype added one arm by exact-anchor replacement: full pgTAP (126 files, 2170 assertions) on a clean reset failed only `58_...` assertions 25–26, which pin the attachment count (27) and table list; `verify_lifecycle_branches.ps1` 122 passed / 0 failed; `scripts/verify_database.sql` ALL CHECKS PASSED; original definition restored to md5 `8c1d62983fcbaffefa5308305ae47985`. |
| Session-less and fixture writes | seeds; migrations; service paths; `26_...` and `101_...` fixtures | VERIFY | The guard's null-`auth.uid()` exemption is unchanged; prototype session-less INSERT succeeded and the full suite's session-less fixtures passed. |
| Status moves and initial state | `app.enforce_status_transition`; canon 26 machine | UNAFFECTED | Status moves already charge `app.authorize` (owner `aal1` direct status UPDATE was refused before repair). Entry into any state is ENTRY-1, a separately owned twelve-table class, and is not changed. |
| Campaign events | `public.events`; entity timeline | UNAFFECTED | Separately reproduced as CAMP-4: at `aal2` the RPC create emitted 1 event and a direct INSERT 0; a direct status UPDATE emitted 0. Different invariant (record, not authority) and different mechanism (an AFTER emitter); recorded OPEN, not repaired here. |
| Pinned catalog shape and measured state | `58_...` assertions 25–26; `MASTER_API_CONTRACT.md` `marketing_campaigns` row; Primary evidence; manifest; disposition; gap register; map | WRITE | Prototype generator run moved exactly one API-contract cell (`marketing_campaigns` guard `no` → `yes`), reverted before drafting. Test 58's count becomes 28 and its list gains `marketing_campaigns`. Primary values are measured after deployment. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 7 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused test, pgTAP A/B, six HTTP suites, smoke and installed mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Test 58 pins the new attachment count and list | BEFORE_IRREVERSIBLE_ACTION | Step 1 | Step 3 | Step 5 |
| Slice-21 findings and 22/77 disposition accurately describe local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Manifest and Primary ledger/function/structure agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 8 | Step 9 |
| API contract and map match generators | BEFORE_COMPLETION | Step 1 | Step 8 | Step 9 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `app.guard_write_capability` runs BEFORE INSERT OR UPDATE on 27 tables, exempts session-less paths, and charges the object-class permission through `app.authorize` (permission AND step-up); it already charges `MANAGE_MARKETING_CAMPAIGN` on the sibling `offline_conversions`. Reuse it by one INSERT-map arm and one attachment, without a new function, permission, policy or grant.

Added Property: every authenticated direct INSERT or UPDATE of a marketing campaign charges `MANAGE_MARKETING_CAMPAIGN` with step-up, exactly as the RPCs do, while `aal2` holders, both RPCs, status transitions, session-less paths and every other table's mapping keep their behaviour.

Causal Negative: An `owner` holding `MANAGE_MARKETING_CAMPAIGN` at `aal1` (`app.has_permission` true, `app.mfa_satisfied` false) was refused by `app.create_marketing_campaign` and in the same transaction directly INSERTed a campaign (1 row) and rewrote an existing campaign's platform, external id and name (1 row); an attributed click then reported the rewritten identity and a squatted external id blocked the genuine RPC registration. Every probe rolled back.

Positive Test Design: One tenant, one visible campaign, an `owner` and an `employee`. At `aal2` the owner's direct INSERT and non-status UPDATE land, and RPC create and advance succeed; a session-less INSERT succeeds; the attachment exists BEFORE INSERT OR UPDATE, enabled, on `app.guard_write_capability`.

Negative Test Design: The owner at `aal1` is refused a direct INSERT and a non-status UPDATE with `42501` and the exact message `multi-factor authentication required for this role`; the row and the tenant's campaign count are unchanged after each refusal. The employee at `aal2` is refused a direct INSERT with the guard's own message, distinguishing it from RLS.

Non-Empty Population Obligation: Prove the campaign exists and is visible to the owner at `aal1`, the owner's `app.has_permission('MANAGE_MARKETING_CAMPAIGN')` is true and `app.mfa_satisfied()` false, the employee's permission is false, and each refused statement targets that same row or tenant.

Mutation Obligation: Disable `marketing_campaigns_guard_write_capability`, positively inspect `tgenabled = 'D'`, and rerun the owner `aal1` INSERT and non-status UPDATE: both must land. Re-enable, prove `tgenabled = 'O'`, prove the same INSERT is refused again, and prove `md5(pg_get_functiondef('app.guard_write_capability()'))` is identical before and after. A failed installation is HARNESS ERROR, never a killed mutant.

Post-Implementation Proof Obligation: Focused test, clean reset, pgTAP A/B, six HTTP suites, smoke, installed/restored mutation, generated artifacts, fresh Primary evidence, parity and repository Gate on final bytes.

## Implementation Steps

1. **Check** that `supabase/migrations/20260926120000_marketing_campaign_step_up_parity.sql` is absent. If absent, create one LF migration that replaces `app.guard_write_capability()` with its current complete installed definition plus exactly one INSERT-map arm, `when 'marketing_campaigns' then array['MANAGE_MARKETING_CAMPAIGN']`, and creates `marketing_campaigns_guard_write_capability` BEFORE INSERT OR UPDATE ON `public.marketing_campaigns` FOR EACH ROW EXECUTE FUNCTION `app.guard_write_capability()`. Preserve signature, SECURITY DEFINER, search path, ACL, every other arm, the UPDATE extra-permission map, the null-session exemption and all error text. Change no RLS policy, grant, event producer or other table. If the target exists with different bytes or the installed source differs from local, stop.
2. **Check** that `supabase/tests/127_marketing_campaign_step_up_parity_test.sql` is absent. If absent, create one LF transaction-rolled-back pgTAP file with a closed-vocabulary `-- ATTACK-CLASSES:` line and an exact `plan(N)` proving the Positive and Negative Test Design, the Non-Empty Population Obligation and the Mutation Obligation. If the target exists with different bytes, stop.
3. **Check** whether `58_write_grants_and_config_capability_test.sql` assertion 25 still expects 27. If so, change only that expected count to 28 with its description, and add `marketing_campaigns` with a one-line SPEC-222 comment to assertion 26's table list; leave `plan(27)` and every other assertion unchanged.
4. **Check** whether `marketing_campaigns` remains `NOT-RECORDED` and CAMP-3/CAMP-4 are absent from the register. If so, register CAMP-3 (Medium, step-up parity at the table door) as fixed by this change and CAMP-4 (Low, direct creation and direct status moves record no event while the RPCs do) as OPEN, set only `marketing_campaigns` to `AUDITED-OPEN` / `ADVERSARIAL` with findings CAMP-3, CAMP-4, and mechanically update Batch-6 coverage to 22/77. Leave CAMP-1, CAMP-2, ENTRY-1, USR-3 and every other finding unchanged. If the current record conflicts, stop.
5. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run clean local reset, focused test, pgTAP Pass A, six declared HTTP suites, pgTAP Pass B without reset, `scripts/verify_database.sql`, plan sum, installed mutation proof, one-arm definition comparison against the prior installed md5, API-contract and map generators, scope, `git diff --check`, repository consistency and parity readiness. Record actual counts, exits and exact SHA-256 hashes. Treat only undeployed Primary/manifest/parity drift as expected at this boundary.
6. **Check** that exact owner authorization for the migration, permanent-test and Test-58 SHA-256 values is recorded in the Execution Log. If absent, stop after Step 5 and present current HEAD, the exact 64-character hashes, fresh full Primary baseline, predicted structural delta and exact Primary write. CR approval does not authorize deployment.
7. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20260926120000_marketing_campaign_step_up_parity`. If absent and separately authorized, immediately re-read HEAD, hashes, project identity, full ordered Primary ledger, target absence, the installed guard md5 and the absence of the new trigger. On exact match apply only the authorized migration. Normalize only its newly inserted ledger row if the connector assigns a temporary version. Read fresh full ledger, function and all ten structural surfaces, the changed definition, security mode, EXECUTE ACL and trigger timing/enabled state. Never contact Secondary.
8. **Check** that fresh Primary evidence contains the unique new migration. If so, update `reports/evidence/primary-ledger-evidence.json` and the manifest only from measured Primary facts; regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` with canonical generators. Run ledger, parity-evidence, repository consistency and `git diff --check`. If Primary is unproven, stop.
9. **Check** for a `Post-deploy local certification` Execution Log entry. If absent, run canonical `-Finish` and require `LOCAL_CERTIFY: READY`; independently Review the committed implementation and every acceptance item. After `Verdict: Confirmed Complete`, set Runtime Checkpoint DONE, transition Complete and clear the manifest pointer. Publish the exact committed candidate, require exact-SHA candidate CI, promote the same accepted SHA, run `-Certify` for `REMOTE_CERTIFY: READY`, verify synchronized clean refs, and remove permitted scratch files. Do not start Slice 22.

## Acceptance Criteria

- [ ] An `owner` at `aal1` holding `MANAGE_MARKETING_CAMPAIGN` cannot directly INSERT a marketing campaign or change a non-status column of one; each refusal is pinned to `multi-factor authentication required for this role` with visible-row and permission controls.
- [ ] `aal2` holders' direct writes, both campaign RPCs, status transitions and session-less paths keep working; a non-holder is refused by the guard's own message; every other table's guard mapping is unchanged and Test 58 pins 28 attachments.
- [ ] CAMP-3 is fixed by the measured guard; CAMP-4 is a separate OPEN finding; ENTRY-1 is untouched; `marketing_campaigns` is `AUDITED-OPEN` / `ADVERSARIAL` and coverage is 22/77.
- [ ] Migration, tests, generated artifacts, local and fresh Primary evidence agree, with no out-of-scope file changes.

## Execution Log

### 2026-09-26 — Owner approval

Owner approved the exact Draft SHA `cf7322379b903713664d12be4a20f1e451cb6d76` and the frozen ten-path Write Scope. An isolated Draft-to-Approved Gate returned `APPROVAL_EVIDENCE: PASS`. Approval authorizes CAMP-3 local implementation and proof, not Primary deployment; Test 58 may change only its guarded-table count (27 to 28) and pinned list. CAMP-4 and ENTRY-1 stay separately owned; PAY-3 and PAY-4 are untouched; `campaign_daily_metrics` is an unmeasured hypothesis only.

### 2026-09-26 — Execution started

The approved ten-path contract entered In Progress. Resume Step 1; only CAMP-3 local implementation and proof are authorized. Primary deployment remains separately gated.

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

EARN IT: the owner at `aal1` was refused by the RPC and wrote the same campaign through the table in the same transaction; the rewrite re-labelled an attributed click and a squatted external id blocked the genuine RPC registration. WORTH IT: the defeated control is the step-up that exists precisely for a password-only session on the two roles holding this capability; the repair is one map arm plus one attachment on a mechanism 27 tables already use. Rejected: adding `app.mfa_satisfied()` to the RLS WITH CHECK (no policy anywhere enforces step-up, measured 0, and its 42501 is indistinguishable from other RLS refusals); a dedicated trigger function in SPEC-203's shape (that shape was needed for `users`' self-reference and self-claim carve-out, neither present here, and would duplicate the existing guard); revoking authenticated INSERT/UPDATE (changes the door model with no canon basis). CAMP-4 and ENTRY-1 have different causes and mechanisms and are intentionally separate. SEC-1b credited this table because RLS charges the permission; it did not consider step-up, which USR-2 established later, so no prior decision is reversed.
