# Change Request — SPEC-304

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Batch 6 Slice 49 makes a document retention period change only with step-up and a record on every door, so an `aal1` session can no longer make a superseded document file deletable and every period that decides a deletion names who set it (RET-3, RET-4; STEPUP-1 loses its `document_retention_policies` member).

## Business Reason

- **Selection.** `scripts/batch6_select_target.ps1` at `53146b3`, on the live local catalog, ranks `document_retention_policies` first: Exposure 6, coverage 36, NOT-RECORDED (runner-up `document_links` 6/54). The manifest's Next capability names that selector, never a copy of its result.
- **Why it matters.** A policy's `retention_days` decides destruction: `app.reconcile_document_storage` marks a superseded version older than its type's active period `retention_expired`, and `app.claim_storage_actions` hands it to the storage executor as `delete_object` unless the document is under legal hold or the tenant is lapsed (RET-1, test 97). No RPC writes the table; its RLS charges `app.has_permission('MANAGE_TENANT_SETTINGS')` only, held by `owner` and `ceo`, both bound to step-up by `app.requires_mfa()`. The legal hold, the lever that overrides retention, charges `app.authorize('MANAGE_TENANT_SETTINGS')`, permission AND step-up, and records every transition as critical (canon 27).
- **Measured at `53146b3`** on the local stack, committed probe fixtures (owner, ceo, finance manager, employee; a lapsed tenant; another tenant's owner):
  - **RET-3 (Medium).** An `owner` at `aal1` inserted a 1-day passport policy and a `ceo` at `aal1` shortened the owner's ten-year visa policy to 1 day; after each, the storage scan made the superseded version a `delete_object` claim (claimable 0 → 1 → 2): an irreversible file deletion on a password alone. The same `aal1` owner is refused the legal hold ("multi-factor authentication required"). The table is a named member of STEPUP-1; this reproduces it with a classified consequence.
  - **RET-4 (Medium).** No creation, shortening, re-type or deactivation was recorded (the tenant's events did not move), and `app.derive_created_by` keeps `created_by` on UPDATE, so after the ceo's shortening the row still named the owner.
- **The repair**, in the SPEC-301 shape (authority BEFORE, record AFTER):
  - `app.guard_document_retention_policy_write`, BEFORE INSERT OR UPDATE (SECURITY DEFINER, empty `search_path`, executable by no client role), session writes only: `app.authorize('MANAGE_TENANT_SETTINGS')` on every column, the legal hold's own charge. A write with no session (migrations, seeds, provisioning, `service_role`, fixtures) is exempt, as in every sibling guard.
  - `app.emit_document_retention_policy_change`, AFTER INSERT OR UPDATE, session writes only: the new code `document_retention_policy_changed` (critical, `sort_order` 938, canon 27 entry) with the actor and the previous and current document type, period, active flag and reason; previous is null on a creation; an update that moves none of them records nothing.
  - No grant, policy, RPC, the scan, the claim or the other four triggers change. DELETE has no grant; withdrawal is deactivation, now charged and recorded.
- **Existing files that move, each for a stated reason.** `10_grant_model_test.sql`: the MEAS-2 inventory of bespoke-guard tables goes from thirteen to fourteen; the assertion exists to force this justification. `scripts/verify_database.sql`: CHECK 6b 625 to 626 catalog values. `_ORVION_CANONICAL/27_event_catalog.md`: the new code's entry. No other test moves.
- **Swept and found sound, pinned rather than changed:** relocation to another tenant and another tenant's writes are refused by RLS; a finance manager is refused; a period below one day is refused by the CHECK (test 97); a lapsed tenant is refused by the subscription write gate; the legal hold still blocks the claim (test 116).
- **Recorded positions, not repaired:** a re-type moves a period to another document type (within the same authority, now charged and recorded); `created_at` and `updated_at` are caller-supplied on INSERT and read by nothing that decides (SPEC-216's schema-wide question).
- **Latent on Primary:** `vrvtsxexkiiiivlkdxzp` holds 0 tenants, 0 retention policies, 0 documents and 0 versions (read-only, 2026-11-11, ledger 258), so no stored row is affected and no data repair is needed.

## Risks

- **A password-only owner or ceo can no longer set, change or deactivate a retention period** (42501); they step up first, as for the legal hold. No RPC, client or script writes the table; tests 97, 49, 116, 135, 60 and 52, which write policies as session-less fixtures, pass unchanged.
- **A new event code** is registered in the migration and canon 27; `app.record_event` refuses an unregistered code, so the code and its emitter ship together.
- **Primary deployment is irreversible** and runs only under the exact-SHA Gate-2 record of Step 9. Approval of this contract does not authorize it. Secondary `brplkqmbzffpxqgkkdzo` is never contacted.
- **Gate 1 and Gate 2 of this contract are DELEGATED** under the owner's instructions (class authorization for Batch 6 releases and standing approval of proposals, 2026-11-08 ~10:20 Cairo; publish, promote and hosted deploy ~12:05; run mode 2 for slice 7, 2026-11-11 ~19:50 Cairo, decision 8), recorded outside this repository; never a human-typed digest.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-304-a-retention-period-changes-only-with-step-up-and-a-record.md`
- `supabase/migrations/20261111150000_a_retention_period_changes_only_with_step_up_and_a_record.sql`
- `supabase/tests/164_a_retention_period_changes_only_with_step_up_and_a_record_test.sql`
- `supabase/tests/10_grant_model_test.sql`
- `scripts/verify_database.sql`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607054900_document_retention_and_storage_reconciliation.sql`
- `supabase/migrations/202607055300_storage_executor_contract.sql`
- `supabase/migrations/202607056400_created_by_is_derived_not_declared.sql`
- `supabase/migrations/202607060500_retention_becomes_a_policy_per_document_type.sql`
- `supabase/migrations/20260909180403_a_legal_hold_always_overrides_retention.sql`
- `supabase/migrations/20260924140000_document_door_parity.sql`
- `supabase/migrations/20261111140000_a_role_grant_changes_only_by_revoke_and_assign.sql`
- `supabase/tests/49_document_retention_test.sql`
- `supabase/tests/52_public_api_and_executor_contract_test.sql`
- `supabase/tests/60_storage_backlog_observability_test.sql`
- `supabase/tests/97_retention_policy_per_document_type_test.sql`
- `supabase/tests/116_document_legal_hold_retention_override_test.sql`
- `supabase/tests/135_document_version_clock_and_object_test.sql`
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
- `supabase/migrations/202607060500_retention_becomes_a_policy_per_document_type.sql` (the table, its policies, the scan and the claim, RET-1) and `20260909180403_a_legal_hold_always_overrides_retention.sql` (the legal hold's charge and record)
- `supabase/tests/97_retention_policy_per_document_type_test.sql` and `116_document_legal_hold_retention_override_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md` (RET-1, STEPUP-1, DOC-7); `reports/master/MASTER_SURFACE_DISPOSITION.md`; `reports/master/MASTER_EXECUTION_PLAN.md`, Batch 6 method, EC-1…EC-11
- `changes/SPEC-301-a-department-stays-in-its-branch-and-changes-only-with-authority-and-a-record.md` (the guard and emitter shape with a new event code)

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

Pass 1 Design: one BEFORE INSERT OR UPDATE guard on `document_retention_policies`, session writes only, charges the legal hold's `app.authorize('MANAGE_TENANT_SETTINGS')` on every column; one AFTER INSERT OR UPDATE emitter records every creation and every change of type, period, active flag or reason with a new critical code; test 164 pins each refusal at `aal1` beside the legal hold's, the stepped-up writes and their single records, a no-op update, the period floor, another tenant's owner, a non-holder and the session-less exemption; test 10 and the smoke count move with stated reasons; the register and disposition record RET-3, RET-4, the STEPUP-1 member and the surface.

Pass 2 Adversarial Review: the design was challenged on the prototype. Charging the step-up in the RLS policies was rejected: a policy filters rows instead of raising, so a refused UPDATE would touch 0 rows and look like success (the SPEC-203 shape). Revoking INSERT and UPDATE from `authenticated` behind a new RPC was rejected: a new client surface, API contract and journey for a table whose only flaw is the missing step-up and record; the table door stays the designed door, as for SPEC-301. Reusing the legal hold's codes was rejected: they describe a document's hold, not a type's period. Recording with severity `info` was rejected: a period decides destruction exactly as a hold does, and canon 27 marks the hold critical for that reason. Refusing session-less writes too was rejected: every sibling guard exempts them, and provisioning and every retention test's fixture write without a session. Refusing a re-type, or caller-supplied `created_at`/`updated_at`, was kept as recorded positions with no deciding reader. Attacks run on the final bytes: tests 97, 49, 116, 135, 60 and 52, which write policies, pass unchanged because their fixtures are session-less; the guard charges `app.authorize`, so test 10's MEAS-2 inventory moves from thirteen to fourteen and the smoke count from 625 to 626 (a first full suite run found exactly those two and nothing else); the API contract does not move, because no RPC changes. Copying the selector's next target into the manifest was rejected (SPEC-270; SPEC-278's cancellation).

Pass 3 Evidence Refresh: 2026-11-11. Re-measured on byte-identical files in a disposable clone of `53146b3` with the project-local CLI 3.0.0: the clean reset, test 164 and tests 10, 97 and 116 alone, pgTAP Pass A and B, the three declared HTTP suites, smoke, the probes, all four mutants, the causal negative, the structural fingerprints before and after, the generators and repository consistency; and Primary and Founder Secondary read read-only for their ledgers, policies, documents and versions.

Selected Version: SPEC-304; selected: the smallest repair that closes RET-3 and RET-4 on every session path (one guard that charges the legal hold's own permission and step-up, one emitter with one new code; no grant, policy, RPC or reader changed), proven on byte-identical files by the full local protocol, four killed mutants, the probes and the causal negative

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Every session write of a retention policy is charged with permission and step-up | the owner's and ceo's table door (RLS insert and update); any platform writer | WRITE | Migration SHA-256 `c2a07757a5f6010e55999a78bce551327173dcccffa6904b6863faf841e1c506`, md5 `445914a298cb4e053a71017048fbddfd`, 5531 bytes, LF, ASCII. A clean reset gives 259 migrations, latest `20261111150000`; guard `md5(prosrc)` `4f51b82e640f070ad91ed6e61f6dfb48`, SECURITY DEFINER, ACL `{postgres=X/postgres}`; trigger `document_retention_policies_guard_write` BEFORE INSERT OR UPDATE. |
| Every policy change is recorded once | readers of `public.events`; canon 27; `catalog_values` (`event_type`) | WRITE | Emitter `md5(prosrc)` `221826baf9571d7b9a34882c9f754be4`, SECURITY DEFINER, ACL `{postgres=X/postgres}`; trigger `document_retention_policies_emit_change` AFTER INSERT OR UPDATE; one new code at `sort_order` 938, catalog 71/625 → 71/626. |
| The readers of policies | `app.reconcile_document_storage`; `app.claim_storage_actions`; `app.document_retention_days`; the legal hold | VERIFY | No body changes; tests 97, 49, 116, 135, 60 and 52 pass unchanged; the probes after the repair find no claim from a refused `aal1` write. |
| Test 164 | `supabase/tests` | WRITE | SHA-256 `00cd21e6f05c5b7d24e570de02f26f003610cf4ea80d403ae1aaba639b76d802`, md5 `16bcb93246eb6f121927d05e911f300a`, 8774 bytes, LF, ASCII, `plan(15)`: 15/15. |
| Test 10 | the MEAS-2 inventory | WRITE | The edit and its reason in Business Reason; it passes alone. |
| Smoke | `scripts/verify_database.sql` | WRITE | CHECK 6b expects 626 catalog values; `ALL CHECKS PASSED` (78 tables, 71/626 catalog). |
| Other tests and the suite | the full pgTAP suite; the HTTP suites | VERIFY | Pass A `Files=164, Tests=3101`, PASS; HTTP 35/0, 85/0, 122/0; Pass B 164/3101, PASS. 164 files whose literal `plan(N)` values sum to 3101. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | Before (258): functions `1273cd1b48c879d51aedce0e9818f89b`/337, `_combined` `48183b9ce5d79728a1a952f38cbfbbc3`/3152, equal to the recorded Primary evidence. After (259, local): functions `e11c0124eec937fa08c1f7fe567b1249`/339 (+2), triggers `b5c21e213844e603ed5e1a6f9b0be455`/326 (+2), `_combined` `0e398aeac8e622fabeda83ac1900bf9d`/3156; policies, constraints, grants, columns, views, indexes, status transitions and RLS unchanged. Step 11 writes Primary values only from fresh post-deploy readings. |
| Client API | `MASTER_API_CONTRACT.md` (Check L3) | VERIFY | No RPC is added, removed or changed; the two functions are trigger functions executable by no client role; the generator's output is identical to the stored file. It is in Write Scope because mandatory Check L3 regenerates it; Step 11 confirms it unchanged. |
| Measured state that moves | manifest `Live state` and suite figure; `primary-ledger-evidence.json`; `ai-map.json` and `repository-index.md` | WRITE | 258 → 259 migrations, latest `20261111150000`, ledger fingerprint `cfd3fcd7719bb2b519efd4bf700636ac`; 163 → 164 files and 3086 → 3101 assertions; coverage 49 → 50 of 78. Tables 78 and client RPCs 80 do not move. `Next capability` and `Current Module` stay unchanged (selector form). |
| The pinned manifest lines `Current Module`, `Next capability` and `Batch 6 surface coverage` | native Boot; `scripts/batch6_select_target.ps1` and `MASTER_SURFACE_DISPOSITION.md`, which own their values (GOVERNANCE.md §6 rule 10) | UNAFFECTED | Step 12 names `Current Module` and `Next capability` only to leave them unchanged; each line keeps its ratified text and pin. |
| RET-3 and RET-4 fixed; STEPUP-1 noted; the surface recorded | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24, 25, 29 | WRITE | No `RET-3` or `RET-4` row exists at `53146b3`. Test 164's `-- ATTACK-CLASSES:` line declares ten classes with STATE, CONCURRENCY and REPLAY `=N/A` and carries negative assertions, so Check 24 admits `ADVERSARIAL`. Each RET row has Owner `—` and is settled. Coverage 50: 26 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 28 `NOT-RECORDED`; all 50 `ADVERSARIAL`. |
| Repository consistency | `scripts/check_repository_consistency.ps1` | VERIFY | With Steps 1–7 applied and the contract present, consistency reports exactly the six measured-state items (258 vs 259 migrations, latest, ledger fingerprint, 163 vs 164 files, 3086 vs 3101 assertions, the Primary-evidence record) and Checks 21–29 pass. Step 11 makes them true; the one implementation commit is made only after it. |
| The four CI-only guard self-tests | `scripts/test_*_guard.ps1`; `orvion-acceptance` | VERIFY | Unchanged scripts, run by `orvion-acceptance` on the exact candidate SHA before `main` may move to it; their controls require the measured state of Step 11, so they are not run locally (timed once in slice 47: 618 s locally, 84 s in hosted CI). |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 10 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| The applied files equal the verified bytes, and the focused tests, probes, mutants and causal negative hold | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 8 |
| Primary lacks the target migration and its ledger and structure equal the recorded evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 10 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 11 | Step 12 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 2 | Step 11 | Step 12 |
| The map matches its generators | BEFORE_COMPLETION | Step 1 | Step 11 | Step 12 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: the RLS insert and update policies charge `app.has_permission('MANAGE_TENANT_SETTINGS')` with no step-up; `app.derive_created_by` fixes `created_by` at creation only; the legal hold's guard and event trigger cover `documents.legal_hold_active`, not a policy. Nothing charges step-up on, or records, a retention period.

Added Property: For every session, a document retention policy is created or changed only by a holder of MANAGE_TENANT_SETTINGS who has satisfied step-up where the role requires it, and every creation and every change of type, period, active flag or reason is recorded once with its actor and both values.

Causal Negative: On the stack with the guard's and the emitter's triggers removed (the `53146b3` schema), test 164 fails assertions 1, 3, 5–7, 9–10 and 14, and the probes return: the `aal1` owner's 1-day policy and the `aal1` ceo's shortening land with 0 events, and each makes a superseded version a `delete_object` claim.

Positive Test Design: One tenant with an owner, a ceo and a finance manager and a visa document; another tenant with an owner. Positive controls: the stepped-up owner sets a ten-year period through the door and the stepped-up ceo changes it to thirty days, each recorded once; an update that changes nothing lands without a record; a session-less platform write lands without a record.

Negative Test Design:
- **Auth:** at `aal1` the legal hold is refused 42501 (control), and so are the owner's creation and the ceo's shortening and deactivation.
- **Tenant:** another tenant's stepped-up owner is refused 42501 (RLS).
- **Door:** the table door is the only writer and is charged on INSERT and UPDATE; DELETE has no grant.
- **Input:** a period below one day is refused 23514.
- **Privilege:** a stepped-up finance manager, holding no MANAGE_TENANT_SETTINGS, is refused 42501.
- **Business:** a shortened period is a deletion decision, so it carries the legal hold's charge.
- **Observability:** each creation and change is recorded once, critical, with the actor, the previous and current values and the reason; the no-op update and the session-less write record nothing.

Non-Empty Population Obligation: The fixture holds two tenants, four users, four grants and one document before the first assertion. Each refusal is asserted by exact SQLSTATE and each record by its exact field list.

Mutation Obligation: Each mutant is installed inside test 164's own rolled-back transaction, proven installed by a changed fingerprint (the guard's `md5` or the table's trigger count, printed as a diag line), run, and rolled back; the restored shape (`md5(pg_get_functiondef)` of the guard `6b1902b9…` and the emitter `9f604413…`, 6 triggers) is read after the last. A mutant not proven installed is a harness error, never a kill.

| Mutant | Change | Killed on the prototype by |
| --- | --- | --- |
| M1 | the guard trigger dropped | 164 assertions 1, 3, 6–7, 9–10 and 14 |
| M2 | the guard charges the permission without step-up | 164 assertions 3, 6–7, 9–10 and 14 |
| M3 | the emitter trigger dropped | 164 assertions 1, 5 and 9–10 |
| M4 | the emitter fires on INSERT only | 164 assertions 1 and 9–10 |

Post-Implementation Proof Obligation: All of the following on the final bytes, through canonical `-Finish` from the main checkout with the project-local CLI: the clean reset, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke; the generated artifacts, repository consistency and the recorded Primary evidence. Before Step 10: the focused tests, the probes, the mutants, the causal negative and the fresh Primary baseline of Step 8.

## Implementation Steps

1. Check whether `supabase/migrations/20261111150000_a_retention_period_changes_only_with_step_up_and_a_record.sql` contains `Batch 6 slice 49 (RET-3, RET-4)`; if so record Already Applied when its Git blob is 5fb9f69fe762979395ecbe04d90e1f9b59ee6db3, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the migration: the retention-policy guard, the emitter and its code), and change nothing else:

   ```text
   -- Batch 6 slice 49 (RET-3, RET-4) -- a document retention period changes only with step-up and a
   -- record.
   --
   -- =================================================================================================
   -- THE MEASURED DEFECTS (2026-11-11 at 53146b3 on the local stack, committed probe fixtures)
   --
   -- RET-3 The table is its own only writer: no RPC writes `document_retention_policies`, and its RLS
   --      charges `app.has_permission('MANAGE_TENANT_SETTINGS')` only, held by `owner` and `ceo`, both
   --      bound to step-up by `app.requires_mfa()`. An `owner` at `aal1` inserted a 1-day passport
   --      policy and a `ceo` at `aal1` shortened the owner's ten-year visa policy to 1 day; after each,
   --      `app.reconcile_document_storage` marked the superseded version `retention_expired` and
   --      `app.claim_storage_actions` handed it out as `delete_object`. The legal hold, the lever that
   --      overrides retention, refuses the same `aal1` owner through `app.authorize`. A member of
   --      STEPUP-1, reproduced with a classified consequence: an irreversible file deletion on a
   --      password alone.
   -- RET-4 No policy change was recorded on any path, and `derive_created_by` keeps the creator on an
   --      UPDATE, so after the ceo's shortening the row still named the owner: nothing recorded who set
   --      the period that deletes a file.
   --
   -- =================================================================================================
   -- THE REPAIR, IN THE SPEC-301 SHAPE: authority is a precondition and runs BEFORE; the record is a
   -- fact and runs AFTER.
   --
   -- 1. `app.guard_document_retention_policy_write`, BEFORE INSERT OR UPDATE: `app.authorize(
   --    'MANAGE_TENANT_SETTINGS')` on every session write, every column, the legal hold's own charge.
   --    No session (migrations, seeds, provisioning, service_role, the tests' fixtures): no charge, as
   --    in every sibling guard.
   -- 2. `app.emit_document_retention_policy_change`, AFTER INSERT OR UPDATE, session writes only: the
   --    NEW code `document_retention_policy_changed` (critical, the legal hold's severity, since either
   --    decides whether a file may be destroyed) with the actor, the previous and the current
   --    document type, period, active flag and reason; previous is null on a creation. An UPDATE that
   --    moves none of them records nothing.
   --
   -- DELETE is not included: `authenticated` holds no DELETE on this table; withdrawal is deactivation.
   -- NOT CHANGED: every grant and policy, the other four triggers, the scan and the claim, RET-1's
   -- retain-by-default shape and test 97.
   -- Hosted rows at the time of writing (read-only, ledger 258): 0 policies on Primary and on Founder
   -- Secondary.
   -- =================================================================================================

   -- Vocabulary. `sort_order` 938 is MEASURED: `event_type` holds 190 rows, maximum 937. Canon 27 gains
   -- the matching entry.
   insert into public.catalog_values (tenant_id, catalog_type_code, code, label, sort_order, is_active, is_system)
   select null::uuid, 'event_type', 'document_retention_policy_changed', 'Document Retention Policy Changed', 938, true, true
   where not exists (
       select 1 from public.catalog_values cv
       where cv.catalog_type_code = 'event_type' and cv.code = 'document_retention_policy_changed'
         and cv.tenant_id is null
   );

   create or replace function app.guard_document_retention_policy_write()
   returns trigger
   language plpgsql
   security definer
   set search_path = ''
   as $fn$
   begin
       if (select auth.uid()) is null then
           return new;
       end if;
       perform app.authorize('MANAGE_TENANT_SETTINGS');
       return new;
   end;
   $fn$;

   revoke execute on function app.guard_document_retention_policy_write() from public;

   create trigger document_retention_policies_guard_write
       before insert or update on public.document_retention_policies
       for each row execute function app.guard_document_retention_policy_write();

   -- `old` is read only inside the UPDATE branch (the SPEC-159-A 55000 failure mode).
   create or replace function app.emit_document_retention_policy_change()
   returns trigger
   language plpgsql
   security definer
   set search_path = ''
   as $fn$
   declare
       v_prev jsonb;
       v_next jsonb;
       v_prev_state text;
   begin
       if (select auth.uid()) is null then
           return null;
       end if;

       v_next := jsonb_build_object('document_type_code', new.document_type_code,
           'retention_days', new.retention_days, 'is_active', new.is_active, 'reason', new.reason);
       if tg_op = 'UPDATE' then
           v_prev := jsonb_build_object('document_type_code', old.document_type_code,
               'retention_days', old.retention_days, 'is_active', old.is_active, 'reason', old.reason);
           if v_prev = v_next then
               return null;
           end if;
           v_prev_state := case when old.is_active then 'active' else 'inactive' end;
       end if;

       perform app.record_event(
           new.tenant_id, 'document_retention_policy_changed', 'document_retention_policy', new.id, null,
           v_prev_state,
           case when new.is_active then 'active' else 'inactive' end, new.reason,
           jsonb_build_object('previous', v_prev, 'current', v_next),
           'critical');
       return null;
   end;
   $fn$;

   revoke execute on function app.emit_document_retention_policy_change() from public;

   create trigger document_retention_policies_emit_change
       after insert or update on public.document_retention_policies
       for each row execute function app.emit_document_retention_policy_change();
   ```

   The resulting file's Git blob is 5fb9f69fe762979395ecbe04d90e1f9b59ee6db3.

2. Check whether `supabase/tests/164_a_retention_period_changes_only_with_step_up_and_a_record_test.sql` contains `plan(15)`; if so record Already Applied when its Git blob is 494d6a07c911412116bfcb652ad1b8533659782b, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (test 164, 15 assertions), and change nothing else:

   ```text
   -- pgTAP: Batch 6 slice 49 (RET-3, RET-4) --
   -- a document retention period changes only with step-up and a record on every door
   -- (`20261111150000`).
   -- ATTACK-CLASSES: AUTH TENANT DOOR STATE=N/A INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS OBSERVABILITY
   --   STATE=N/A -- a policy has no lifecycle beyond its active flag, whose change is charged and recorded here.
   --   CONCURRENCY=N/A -- one row per tenant and type, held by the existing unique index.
   --   REPLAY=N/A -- no token, nonce or idempotency key on this surface.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(15);

   insert into auth.users (id, email) values
     ('16400000-0000-0000-0000-0000000000a1','owner@c164.test'),
     ('16400000-0000-0000-0000-0000000000a2','ceo@c164.test'),
     ('16400000-0000-0000-0000-0000000000a3','fm@c164.test'),
     ('16400000-0000-0000-0000-0000000000a9','other@c164.test');
   insert into public.tenants (id, name, slug, status) values
     ('16400000-0000-0000-0000-000000000001','Retention Travel','retention-travel-164','active'),
     ('16400000-0000-0000-0000-000000000002','Other Travel','other-travel-164','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select t.id, sp.id, 'active' from public.subscription_plans sp cross join (values ('16400000-0000-0000-0000-000000000001'::uuid), ('16400000-0000-0000-0000-000000000002'::uuid)) t(id) where sp.plan_code = 'enterprise';
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('16400000-0000-0000-0000-000000000011','16400000-0000-0000-0000-000000000001','Owner','owner@c164.test',true,'16400000-0000-0000-0000-0000000000a1'),
     ('16400000-0000-0000-0000-000000000012','16400000-0000-0000-0000-000000000001','CEO','ceo@c164.test',true,'16400000-0000-0000-0000-0000000000a2'),
     ('16400000-0000-0000-0000-000000000013','16400000-0000-0000-0000-000000000001','FM','fm@c164.test',true,'16400000-0000-0000-0000-0000000000a3'),
     ('16400000-0000-0000-0000-000000000019','16400000-0000-0000-0000-000000000002','Other','other@c164.test',true,'16400000-0000-0000-0000-0000000000a9');
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select v.tid, v.uid, r.id, 'tenant'
   from (values ('16400000-0000-0000-0000-000000000001'::uuid,'16400000-0000-0000-0000-000000000011'::uuid,'owner'),
                ('16400000-0000-0000-0000-000000000001','16400000-0000-0000-0000-000000000012','ceo'),
                ('16400000-0000-0000-0000-000000000001','16400000-0000-0000-0000-000000000013','finance_manager'),
                ('16400000-0000-0000-0000-000000000002','16400000-0000-0000-0000-000000000019','owner')) v(tid, uid, role_code)
   join public.roles r on r.code = v.role_code;
   insert into public.documents (id, tenant_id, document_type_code, title, lifecycle_status_code) values
     ('16400000-0000-0000-0000-0000000000d1','16400000-0000-0000-0000-000000000001','visa','V','active');

   select is(
     (select count(*)::int from pg_trigger
      where tgrelid = 'public.document_retention_policies'::regclass and not tgisinternal
        and tgname in ('document_retention_policies_guard_write', 'document_retention_policies_emit_change')
        and pg_get_triggerdef(oid) like '%INSERT OR UPDATE%'),
     2,
     'the guard and the emitter both fire on INSERT and UPDATE');

   -- The owner at aal1: the legal hold refuses it (control), and now so does the retention period.
   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"16400000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
   select throws_ok(
     $$select app.set_document_legal_hold('16400000-0000-0000-0000-0000000000d1', true, 'hold')$$,
     '42501', null,
     'control: the legal hold, the lever that overrides retention, refuses a password-only owner');
   select throws_ok(
     $$insert into public.document_retention_policies (tenant_id, document_type_code, retention_days, reason)
       values ('16400000-0000-0000-0000-000000000001', 'passport', 1, 'one day')$$,
     '42501', null,
     'RET-3: a 1-day policy at aal1 is refused (measured before the repair: created, and a superseded version became a delete_object claim)');

   select set_config('request.jwt.claims', '{"sub":"16400000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
   select lives_ok(
     $$insert into public.document_retention_policies (id, tenant_id, document_type_code, retention_days, reason)
       values ('16400000-0000-0000-0000-0000000000e1', '16400000-0000-0000-0000-000000000001', 'visa', 3650, 'ten years')$$,
     'the stepped-up owner still sets a period through the table door');
   select is(
     (select count(*)::int from public.events
      where entity_id = '16400000-0000-0000-0000-0000000000e1' and event_type_code = 'document_retention_policy_changed'
        and severity_code = 'critical' and actor_user_id = '16400000-0000-0000-0000-000000000011'
        and payload->'previous' = 'null'::jsonb and (payload->'current'->>'retention_days')::int = 3650
        and new_state = 'active' and reason = 'ten years'),
     1,
     'RET-4: the creation is recorded once, critical, with the actor and the period (measured before the repair: 0 events)');

   -- The ceo at aal1 can neither shorten nor deactivate it.
   select set_config('request.jwt.claims', '{"sub":"16400000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
   select throws_ok(
     $$update public.document_retention_policies set retention_days = 1 where id = '16400000-0000-0000-0000-0000000000e1'$$,
     '42501', null,
     'RET-3: shortening at aal1 is refused (measured before the repair: shortened to 1 day)');
   select throws_ok(
     $$update public.document_retention_policies set is_active = false where id = '16400000-0000-0000-0000-0000000000e1'$$,
     '42501', null,
     'RET-3: every column is charged, deactivation included');

   select set_config('request.jwt.claims', '{"sub":"16400000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
   select lives_ok(
     $$update public.document_retention_policies set retention_days = 30, reason = 'thirty days' where id = '16400000-0000-0000-0000-0000000000e1'$$,
     'the stepped-up ceo changes the period');
   select is(
     (select count(*)::int from public.events
      where entity_id = '16400000-0000-0000-0000-0000000000e1' and event_type_code = 'document_retention_policy_changed'
        and actor_user_id = '16400000-0000-0000-0000-000000000012'
        and (payload->'previous'->>'retention_days')::int = 3650 and (payload->'current'->>'retention_days')::int = 30
        and previous_state = 'active' and reason = 'thirty days'),
     1,
     'RET-4: the change is recorded with the ceo as actor and both periods (measured before the repair: unrecorded, the row still named the owner)');

   update public.document_retention_policies set updated_at = now() where id = '16400000-0000-0000-0000-0000000000e1';
   select is(
     (select count(*)::int from public.events
      where entity_id = '16400000-0000-0000-0000-0000000000e1' and event_type_code = 'document_retention_policy_changed'),
     2,
     '...and an update that moves no type, period, flag or reason records nothing');

   select throws_ok(
     $$update public.document_retention_policies set retention_days = 0 where id = '16400000-0000-0000-0000-0000000000e1'$$,
     '23514', null,
     'a period below one day is refused, unchanged (RET-1, test 97)');

   -- Another tenant's owner, stepped up, cannot set this tenant's period.
   select set_config('request.jwt.claims', '{"sub":"16400000-0000-0000-0000-0000000000a9","aal":"aal2"}', true);
   select throws_ok(
     $$insert into public.document_retention_policies (tenant_id, document_type_code, retention_days)
       values ('16400000-0000-0000-0000-000000000001', 'contract', 1)$$,
     '42501', null,
     'another tenant''s owner is refused, unchanged (RLS)');

   -- A finance manager, stepped up, holds no MANAGE_TENANT_SETTINGS.
   select set_config('request.jwt.claims', '{"sub":"16400000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
   select throws_ok(
     $$insert into public.document_retention_policies (tenant_id, document_type_code, retention_days)
       values ('16400000-0000-0000-0000-000000000001', 'contract', 1)$$,
     '42501', null,
     'a non-holder is refused, unchanged');

   -- No session (migrations, provisioning, the tests' own fixtures): no charge and no record.
   reset role;
   select set_config('request.jwt.claims', '', true);
   select lives_ok(
     $$insert into public.document_retention_policies (id, tenant_id, document_type_code, retention_days)
       values ('16400000-0000-0000-0000-0000000000e2', '16400000-0000-0000-0000-000000000001', 'passport', 365)$$,
     'a session-less write is not charged');
   select is(
     (select count(*)::int from public.events where entity_id = '16400000-0000-0000-0000-0000000000e2'),
     0,
     '...and records nothing, as before');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 494d6a07c911412116bfcb652ad1b8533659782b.

3. Check whether `supabase/tests/10_grant_model_test.sql` contains `exactly these FOURTEEN tables`; if so record Already Applied when its Git blob is 10c10ed1fbd8fa0d32e1f3daa59dc86cfc53ee8f, and otherwise stop and report. Otherwise make exactly these 3 edits (the MEAS-2 bespoke-guard inventory, thirteen to fourteen), each matched once, and change nothing else:

   a) immediately after the line
   ```text
   -- the guard.
   ```
   insert
   ```text
   --
   -- IT WENT FROM THIRTEEN TO FOURTEEN ON 2026-11-11 (Batch 6 slice 7, `20261111150000`).
   -- `document_retention_policies` joined because `app.guard_document_retention_policy_write` charges
   -- `app.authorize('MANAGE_TENANT_SETTINGS')` (RET-3: the period that decides a file's destruction now
   -- asks for the step-up the legal hold asks for). `guard_write_capability` has no mapping for this
   -- table. The charge is UNCONDITIONAL for every signed-in caller, on INSERT and UPDATE and every column;
   -- its one exemption, the SESSION-LESS platform write, is pinned by `164_...`, and the slice's mutants
   -- remove the guard.
   ```

   b) replace the line
   ```text
     array['chart_of_accounts','departments','document_versions','invoices','lead_interactions','payment_allocations',
   ```
   with
   ```text
     array['chart_of_accounts','departments','document_retention_policies','document_versions','invoices','lead_interactions','payment_allocations',
   ```

   c) replace the line
   ```text
     'MEAS-2: exactly these THIRTEEN tables are credited by a BESPOKE capability trigger rather than by guard_write_capability, so for each of them "credited" means "a human read its short-circuits". Nine until 2026-09-20, when SPEC-203 gave users app.guard_membership_authority -- admissible only because that guard charges app.authorize unconditionally on every path and every column, and its only two exemptions, the session-less platform write and the activate_membership self-claim, are each pinned by a named assertion in 118_membership_authority_and_audit_test.sql. Eleven since 2026-10-13, when SPEC-278 gave chart_of_accounts app.guard_chart_account -- the same unconditional charge, its one session-less exemption pinned by 157_a_used_ledger_account_keeps_its_meaning_test.sql. Twelve since 2026-11-11, when SPEC-300 gave user_branch_assignments app.guard_placement_authority -- the same unconditional charge, its one session-less exemption pinned by 160_a_placement_changes_only_with_authority_and_a_record_test.sql. Thirteen since 2026-11-11, when Batch 6 slice 4 gave departments app.guard_department_write -- the same unconditional charge, its one session-less exemption pinned by 161_a_department_stays_in_its_branch_and_changes_only_with_authority_and_a_record_test.sql');
   ```
   with
   ```text
     'MEAS-2: exactly these FOURTEEN tables are credited by a BESPOKE capability trigger rather than by guard_write_capability, so for each of them "credited" means "a human read its short-circuits". Nine until 2026-09-20, when SPEC-203 gave users app.guard_membership_authority -- admissible only because that guard charges app.authorize unconditionally on every path and every column, and its only two exemptions, the session-less platform write and the activate_membership self-claim, are each pinned by a named assertion in 118_membership_authority_and_audit_test.sql. Eleven since 2026-10-13, when SPEC-278 gave chart_of_accounts app.guard_chart_account -- the same unconditional charge, its one session-less exemption pinned by 157_a_used_ledger_account_keeps_its_meaning_test.sql. Twelve since 2026-11-11, when SPEC-300 gave user_branch_assignments app.guard_placement_authority -- the same unconditional charge, its one session-less exemption pinned by 160_a_placement_changes_only_with_authority_and_a_record_test.sql. Thirteen since 2026-11-11, when Batch 6 slice 4 gave departments app.guard_department_write -- the same unconditional charge, its one session-less exemption pinned by 161_a_department_stays_in_its_branch_and_changes_only_with_authority_and_a_record_test.sql. Fourteen since 2026-11-11, when Batch 6 slice 7 gave document_retention_policies app.guard_document_retention_policy_write -- the same unconditional charge, its one session-less exemption pinned by 164_a_retention_period_changes_only_with_step_up_and_a_record_test.sql');
   ```

   The resulting file's Git blob is 10c10ed1fbd8fa0d32e1f3daa59dc86cfc53ee8f.

4. Check whether `scripts/verify_database.sql` contains `expected 626 catalog_values`; if so record Already Applied when its Git blob is 1584d5e3e632ac6e9b7ba75be9775d724b3f556f, and otherwise stop and report. Otherwise make exactly these 3 edits (smoke CHECK 6b, 625 to 626 catalog values), each matched once, and change nothing else:

   a) replace the line
   ```text
   -- Expected values track the frozen baseline: 77 public base tables, 71 catalog types, 625 catalog
   ```
   with
   ```text
   -- Expected values track the frozen baseline: 77 public base tables, 71 catalog types, 626 catalog
   ```

   b) replace the line
   ```text
       if n <> 625 then raise exception 'CHECK 6b FAILED: expected 625 catalog_values, found %', n; end if;
   ```
   with
   ```text
       -- 625 -> 626: Batch 6 slice 7 (RET-4) registered document_retention_policy_changed at sort_order 938 --
       -- the record of a retention period set or changed; `app.record_event` refuses an unregistered code.
       if n <> 626 then raise exception 'CHECK 6b FAILED: expected 626 catalog_values, found %', n; end if;
   ```

   c) replace the line
   ```text
       raise notice 'ALL CHECKS PASSED (78 tables, RLS + policies, resolver + read-scope model, 71/625 catalog, FK standard, updated_at triggers, append-only audit, grant/schema-usage completeness)';
   ```
   with
   ```text
       raise notice 'ALL CHECKS PASSED (78 tables, RLS + policies, resolver + read-scope model, 71/626 catalog, FK standard, updated_at triggers, append-only audit, grant/schema-usage completeness)';
   ```

   The resulting file's Git blob is 1584d5e3e632ac6e9b7ba75be9775d724b3f556f.

5. Check whether `_ORVION_CANONICAL/27_event_catalog.md` contains `## document_retention_policy_changed`; if so record Already Applied when its Git blob is 81bd47e0e1fbc0669c0e1a94f1a2f0fc3f057643, and otherwise stop and report. Otherwise make exactly this one edit (the canon entry of the new code), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
   Created for each legal-hold transition with actor and reason. Both are critical because they change destruction eligibility.

   ```
   insert
   ```text
   ## document_retention_policy_changed

   Created for each creation or change of a document type's retention policy (type, period, active flag or reason), on every door, with the actor and the previous and current values; an update that moves none of them records nothing. Critical because a period decides destruction eligibility, as the legal hold does (RET-4, SPEC-304).

   ```

   The resulting file's Git blob is 81bd47e0e1fbc0669c0e1a94f1a2f0fc3f057643.

6. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `| RET-3 |`; if so record Already Applied when its Git blob is d8aa83ed009c1ad2eae9352927f61853f8216aaf, and otherwise stop and report. Otherwise make exactly these 3 edits (the Slice 49 freshness entry, the RET-3 and RET-4 rows and the STEPUP-1 note), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-11 (**Slice 47 — `user_role_assignments` selected live at Exposure 7, coverage 684; runner-up `customer_consents` at 6/18.** **URA-1** (High), **URA-2** (High) and **URA-3** (Medium) are new and fixed. `app.emit_role_change` charged the step-up and wrote the record only when a grant's liveness changed, so a `ceo` at `aal1`, refused by `app.assign_user_role`, re-pointed live grants by direct UPDATE (an employee to `owner`, the owner's grant to another user, a branch scope moved and widened, a start pushed a year ahead), none recorded, and a lone owner demoted their own grant and left the tenant with no administrator. SPEC-302 fixes a grant's identity for every session.)
   ```
   with
   ```text
   Last updated: 2026-11-11 (**Slice 49 — `document_retention_policies` selected live at Exposure 6, coverage 36; runner-up `document_links` at 6/54.** **RET-3** (Medium) and **RET-4** (Medium) are new and fixed. The table is its own only writer and its RLS charged `MANAGE_TENANT_SETTINGS` without step-up, so an `owner` at `aal1` set a 1-day period and a `ceo` at `aal1` shortened a ten-year one to 1 day, and after each the storage scan made a superseded version a `delete_object` claim, while the legal hold that overrides retention refuses the same session; no change was recorded and the ceo's change still named the owner. SPEC-304 charges the step-up and records every change. STEPUP-1 loses its `document_retention_policies` member. No other row changed.)

   Previously: 2026-11-11 (**Slice 47 — `user_role_assignments` selected live at Exposure 7, coverage 684; runner-up `customer_consents` at 6/18.** **URA-1** (High), **URA-2** (High) and **URA-3** (Medium) are new and fixed. `app.emit_role_change` charged the step-up and wrote the record only when a grant's liveness changed, so a `ceo` at `aal1`, refused by `app.assign_user_role`, re-pointed live grants by direct UPDATE (an employee to `owner`, the owner's grant to another user, a branch scope moved and widened, a start pushed a year ahead), none recorded, and a lone owner demoted their own grant and left the tenant with no administrator. SPEC-302 fixes a grant's identity for every session.)
   ```

   b) immediately after the line
   ```text
   | URA-3 | **A tenant's lone owner could leave the tenant with no administrator by re-pointing their own grant (ADMIN-2's protection held for revocation only)** | governance · resilience | Medium | R | 6 | M | ✅ | **✅ FIXED 2026-11-11 (SPEC-302, `20261111140000`), DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-302; the fresh Primary ledger, functions and structure equal local.** **MEASURED** at `03009ec`: the lone owner's revoke was refused (ADMIN-2: the AFTER emitter re-charges MANAGE_USERS once the grant is gone), but the same owner changed their own grant's role to `employee` by direct UPDATE at `aal2` and the tenant was left with 0 MANAGE_USERS holders, unadministrable. **Repaired:** `app.guard_role_assignment_change` (BEFORE UPDATE, SECURITY DEFINER, session writes only) fixes a grant's tenant, holder, role, scope, branch, department, start and creation time (23514), and a live grant's `ends_at` while it stays live; a session changes a grant only by ending it or starting it, which `app.emit_role_change` charges and records. `162_a_role_grant_changes_only_by_revoke_and_assign_test.sql` pins it. The re-point is refused, so ADMIN-2 holds on every session path again. | — | SPEC-302-a-role-grant-changes-only-by-revoke-and-assign | 11-11 | 11-11 |
   ```
   insert
   ```text
   | RET-3 | **An `aal1` owner or ceo set or shortened a document type's retention period at the table, which makes superseded document files deletable, while the legal hold that overrides retention charges step-up** | security · authorization · retention | Medium | R | 6 | M | 🛡 | **FIXED 2026-11-11 locally (SPEC-304, `20261111150000`); Primary deployment pending.** **MEASURED** at `53146b3`: no RPC writes `document_retention_policies`; its RLS charges `app.has_permission('MANAGE_TENANT_SETTINGS')` only, held by `owner` and `ceo`, both bound to step-up by `app.requires_mfa()`. An `owner` at `aal1` inserted a 1-day passport policy and a `ceo` at `aal1` shortened the owner's ten-year visa policy to 1 day; after each, `app.reconcile_document_storage` marked the superseded version `retention_expired` and `app.claim_storage_actions` handed it out as `delete_object` (claimable 0 → 1 → 2), an irreversible file deletion on a password alone. The same `aal1` owner is refused `app.set_document_legal_hold` ("multi-factor authentication required"). The table's member of **STEPUP-1**, reproduced with a classified consequence. **Repaired:** `app.guard_document_retention_policy_write` (BEFORE INSERT OR UPDATE, SECURITY DEFINER, session writes only) charges `app.authorize('MANAGE_TENANT_SETTINGS')`, the legal hold's own charge, on every column; `app.emit_document_retention_policy_change` (AFTER INSERT OR UPDATE) records the new code `document_retention_policy_changed` (critical) with the actor and the previous and current type, period, active flag and reason. `164_a_retention_period_changes_only_with_step_up_and_a_record_test.sql` pins both. | — | SPEC-304-a-retention-period-changes-only-with-step-up-and-a-record | 11-11 | 11-11 |
   | RET-4 | **No change to a document retention policy was recorded, and an UPDATE kept the creator's name, so a file deletion could not be traced to whoever set its period** | audit completeness · observability | Medium | R | 6 | M | 🛡 | **FIXED 2026-11-11 locally (SPEC-304, `20261111150000`); Primary deployment pending.** **MEASURED** at `53146b3`: no trigger or function recorded a policy's creation, shortening, re-type or deactivation (tenant events unchanged across all of them), and `app.derive_created_by` keeps `created_by` on UPDATE, so after the ceo's shortening the row still named the owner. The legal hold, the other retention lever, records every transition as critical (canon 27). **Repaired:** `app.guard_document_retention_policy_write` (BEFORE INSERT OR UPDATE, SECURITY DEFINER, session writes only) charges `app.authorize('MANAGE_TENANT_SETTINGS')`, the legal hold's own charge, on every column; `app.emit_document_retention_policy_change` (AFTER INSERT OR UPDATE) records the new code `document_retention_policy_changed` (critical) with the actor and the previous and current type, period, active flag and reason. `164_a_retention_period_changes_only_with_step_up_and_a_record_test.sql` pins both. A no-change update and a session-less write record nothing. | — | SPEC-304-a-retention-period-changes-only-with-step-up-and-a-record | 11-11 | 11-11 |
   ```

   c) replace the line
   ```text
   | STEPUP-1 | **A class CANDIDATE, found by structural evidence: eleven tables carry a direct permission-only write path with no step-up anywhere in their trigger chain** | security · authorization · class | Unclassified | R | 6 | — | 📋 | **UNPROVEN — structural candidate class, recorded, deliberately not acted on (Batch 6 Slice 24).** Not a reproduced class defect. Criterion, read from the local catalog at `b6a0714`: `authenticated` holds INSERT or UPDATE; the INSERT or UPDATE policy charges `app.has_permission(K)` for a K held only by roles that `app.requires_mfa` binds to step-up; and no trigger on the table, at any timing, calls `app.authorize` or `app.mfa_satisfied` directly or through one level of `app` helper. Eleven tables meet it: `branches`, `campaign_daily_metrics`, `catalog_values`, `chart_of_accounts`, `departments`, `document_retention_policies`, `exchange_rate_adjustments`, `exchange_rates`, `journal_entries`, `journal_entry_lines`, `tenants`. `user_branch_assignments` and `user_permission_grants` meet it too and belong to USR-3. `user_role_assignments` does NOT: its AFTER trigger `app.emit_role_change` charges `app.authorize('MANAGE_USERS')`, which a first, BEFORE-only reading missed and a rolled-back probe corrected. **Only `branches` is a reproduced and consequence-classified defect (BRANCH-1, Low).** **`journal_entry_lines` was audited in Batch 6 Slice 32 (SPEC-245): an `aal1` finance manager rewrote posted lines the RPC refuses it to post, and that member is closed by JE-3's repair; it no longer meets the criterion, because `authenticated` holds no INSERT or UPDATE on it. `chart_of_accounts` was audited in Batch 6 Slice 42 (SPEC-278): its member was reproduced as COA-2 and is closed, and it no longer meets the criterion, because `app.guard_chart_account` charges `app.authorize`. `journal_entries` still meets it (JE-5).** The same probe saw an `aal1` owner's rename land on `departments` and on `tenants`. `departments`' consequence is not classified, so it remains a candidate and is not an audit. **`tenants` was audited in Batch 6 Slice 26 (SPEC-228) and its consequence is classified: none material.** An `aal1` `owner` or `ceo` does write every tenant-profile column, but nothing reads any of them except `name`, shown only to the tenant's own members; no canon marks a tenant-profile edit as step-up, platform-only or sensitive; and the other MANAGE_TENANT_SETTINGS doors that charge `app.authorize` guard distinct actions (licence redemption, payment-proof upload, legal hold, document versions and links, holidays), not a second door to the same action. So `tenants` still meets the criterion, is not a defect, and does not raise this class above UNPROVEN. The other eight are structural candidates only; the finance tables among them are where a consequence, if reproduced, would most likely be material. A member becomes a defect only when it is individually reproduced adversarially and its consequence is classified, and no member gains a disposition or counts toward Batch 6 coverage by being listed here. `campaign_daily_metrics` and `exchange_rate_adjustments` are recorded `AUDITED`, and step-up was not asked on either. **Ceiling:** the criterion reads function text, so it can miss step-up charged through deeper indirection and it cannot see consequence (MEAS-1). **Trigger to revisit:** the Batch 6 slice of any listed table, or the first reproduced consequence on a candidate. **2026-10-08 (SPEC-246): `journal_entries` no longer meets the criterion, because `authenticated` holds no INSERT or UPDATE on it; its member consequence, JE-5, is closed by that revoke.** **2026-11-11 (SPEC-301): `departments` was audited in Batch 6 Slice 46; its member was reproduced as DEP-1 with a classified consequence (DEP-3) and is closed, and it no longer meets the criterion, because `app.guard_department_write` charges `app.authorize`.** | — | SPEC-226-branch-door-audit-record | 09-27 | 09-27 |
   ```
   with
   ```text
   | STEPUP-1 | **A class CANDIDATE, found by structural evidence: eleven tables carry a direct permission-only write path with no step-up anywhere in their trigger chain** | security · authorization · class | Unclassified | R | 6 | — | 📋 | **UNPROVEN — structural candidate class, recorded, deliberately not acted on (Batch 6 Slice 24).** Not a reproduced class defect. Criterion, read from the local catalog at `b6a0714`: `authenticated` holds INSERT or UPDATE; the INSERT or UPDATE policy charges `app.has_permission(K)` for a K held only by roles that `app.requires_mfa` binds to step-up; and no trigger on the table, at any timing, calls `app.authorize` or `app.mfa_satisfied` directly or through one level of `app` helper. Eleven tables meet it: `branches`, `campaign_daily_metrics`, `catalog_values`, `chart_of_accounts`, `departments`, `document_retention_policies`, `exchange_rate_adjustments`, `exchange_rates`, `journal_entries`, `journal_entry_lines`, `tenants`. `user_branch_assignments` and `user_permission_grants` meet it too and belong to USR-3. `user_role_assignments` does NOT: its AFTER trigger `app.emit_role_change` charges `app.authorize('MANAGE_USERS')`, which a first, BEFORE-only reading missed and a rolled-back probe corrected. **Only `branches` is a reproduced and consequence-classified defect (BRANCH-1, Low).** **`journal_entry_lines` was audited in Batch 6 Slice 32 (SPEC-245): an `aal1` finance manager rewrote posted lines the RPC refuses it to post, and that member is closed by JE-3's repair; it no longer meets the criterion, because `authenticated` holds no INSERT or UPDATE on it. `chart_of_accounts` was audited in Batch 6 Slice 42 (SPEC-278): its member was reproduced as COA-2 and is closed, and it no longer meets the criterion, because `app.guard_chart_account` charges `app.authorize`. `journal_entries` still meets it (JE-5).** The same probe saw an `aal1` owner's rename land on `departments` and on `tenants`. `departments`' consequence is not classified, so it remains a candidate and is not an audit. **`tenants` was audited in Batch 6 Slice 26 (SPEC-228) and its consequence is classified: none material.** An `aal1` `owner` or `ceo` does write every tenant-profile column, but nothing reads any of them except `name`, shown only to the tenant's own members; no canon marks a tenant-profile edit as step-up, platform-only or sensitive; and the other MANAGE_TENANT_SETTINGS doors that charge `app.authorize` guard distinct actions (licence redemption, payment-proof upload, legal hold, document versions and links, holidays), not a second door to the same action. So `tenants` still meets the criterion, is not a defect, and does not raise this class above UNPROVEN. The other eight are structural candidates only; the finance tables among them are where a consequence, if reproduced, would most likely be material. A member becomes a defect only when it is individually reproduced adversarially and its consequence is classified, and no member gains a disposition or counts toward Batch 6 coverage by being listed here. `campaign_daily_metrics` and `exchange_rate_adjustments` are recorded `AUDITED`, and step-up was not asked on either. **Ceiling:** the criterion reads function text, so it can miss step-up charged through deeper indirection and it cannot see consequence (MEAS-1). **Trigger to revisit:** the Batch 6 slice of any listed table, or the first reproduced consequence on a candidate. **2026-10-08 (SPEC-246): `journal_entries` no longer meets the criterion, because `authenticated` holds no INSERT or UPDATE on it; its member consequence, JE-5, is closed by that revoke.** **2026-11-11 (SPEC-301): `departments` was audited in Batch 6 Slice 46; its member was reproduced as DEP-1 with a classified consequence (DEP-3) and is closed, and it no longer meets the criterion, because `app.guard_department_write` charges `app.authorize`.** **2026-11-11 (SPEC-304): `document_retention_policies` was audited in Batch 6 Slice 49; its member was reproduced as RET-3 with a classified consequence (a superseded file made deletable at `aal1`) and is closed, and it no longer meets the criterion, because `app.guard_document_retention_policy_write` charges `app.authorize`.** | — | SPEC-226-branch-door-audit-record | 09-27 | 09-27 |
   ```

   The resulting file's Git blob is d8aa83ed009c1ad2eae9352927f61853f8216aaf.

7. Check whether `reports/master/MASTER_SURFACE_DISPOSITION.md` contains `**50 of 78 recorded · 26 `; if so record Already Applied when its Git blob is 163277642499317f9c4d852b76e7dd8b3f12afb8, and otherwise stop and report. Otherwise make exactly these 4 edits (the freshness entry, coverage 50 of 78 and the document_retention_policies row), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-11 (**slice 48 — `customer_consents` selected by Exposure 6, coverage 18; runner-up `document_retention_policies` at 6/36.** Coverage **48 → 49 of 78**. No finding: the writer's step-up, the archived customer's withdrawal and the lapsed tenant's GRANT are pinned; the door, tenant, privilege and input attacks held again and stay pinned by tests 142 and 144; `service_role`'s TRUNCATE is DC-15's. SPEC-303 records it, so the row is `AUDITED`. No other row changed.)
   ```
   with
   ```text
   Last updated: 2026-11-11 (**slice 49 — `document_retention_policies` selected by Exposure 6, coverage 36; runner-up `document_links` at 6/54.** Coverage **49 → 50 of 78**. RET-3: an `owner` or `ceo` at `aal1` set or shortened a retention period at the table, and a superseded version became a `delete_object` claim, while the legal hold refuses the same session. RET-4: no policy change was recorded. SPEC-304 closes both here, so the row is `AUDITED`.)

   Previously: 2026-11-11 (**slice 48 — `customer_consents` selected by Exposure 6, coverage 18; runner-up `document_retention_policies` at 6/36.** Coverage **48 → 49 of 78**. No finding: the writer's step-up, the archived customer's withdrawal and the lapsed tenant's GRANT are pinned; the door, tenant, privilege and input attacks held again and stay pinned by tests 142 and 144; `service_role`'s TRUNCATE is DC-15's. SPEC-303 records it, so the row is `AUDITED`. No other row changed.)
   ```

   b) replace the line
   ```text
   **49 of 78 recorded · 25 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 29 `NOT-RECORDED`.**
   ```
   with
   ```text
   **50 of 78 recorded · 26 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 28 `NOT-RECORDED`.**
   ```

   c) replace the line
   ```text
   **All 49 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```
   with
   ```text
   **All 50 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```

   d) replace the line
   ```text
   | `document_retention_policies` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `document_retention_policies` | **AUDITED** | ADVERSARIAL | `SPEC-304-a-retention-period-changes-only-with-step-up-and-a-record` | RET-3, RET-4 | `164_a_retention_period_changes_only_with_step_up_and_a_record_test.sql` (15 assertions, ten attack classes declared, STATE, CONCURRENCY and REPLAY N/A) proves that a password-only (`aal1`) owner is refused a period at the table as the legal hold refuses it, and a password-only ceo is refused shortening or deactivating one; that a stepped-up owner and ceo still set and change a period through the table door, each recorded once as `document_retention_policy_changed` with the actor and both values; that a no-change update and a session-less write record nothing; and that a period below one day, another tenant's owner and a finance manager are refused. Test 97 keeps RET-1's retain-by-default shape and the period floor. **Swept and classified as non-defects:** relocation to another tenant and another tenant's writes (refused by RLS); no DELETE grant (withdrawal is deactivation, now charged and recorded); a lapsed tenant (refused by the subscription write gate); a re-type moves a period to another document type, now charged and recorded; caller-supplied `created_at`/`updated_at` on INSERT are read by nothing that decides (SPEC-216's schema-wide question); the legal hold still blocks the claim. 0 hosted policies and documents. |
   ```

   The resulting file's Git blob is 163277642499317f9c4d852b76e7dd8b3f12afb8.

8. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, with Steps 1–7 applied and uncommitted in the main checkout, run with the project-local CLI and record, with actual counts, exits and exact SHA-256 values:
   - the SHA-256, md5 and byte counts of the migration and test 164, which must equal Consumer Closure;
   - on the local stack holding the migration: the guard's and the emitter's `md5(prosrc)`, security mode and ACL, their triggers, and the catalog count; test 164 and tests 10, 97 and 116 alone; the probes; mutants M1–M4, the restored shape proven equal;
   - the causal negative on a local stack without the migration, then the stack restored with it;
   - the local structural fingerprints of `scripts/parity_surface.sql`, before and after the migration;
   - the API-contract and map generators, the scope check and `git diff --check`.

   Treat as expected at this boundary only: an undeployed Primary and the six measured-state items of Consumer Closure.

   Read a fresh Primary baseline, read-only: the project URL, the full ordered ledger and the absence of the target migration; the function and structural surfaces; the triggers of `document_retention_policies`, the absence of both functions and of the new code; the tenant, policy, document and version counts. Record the predicted delta. If any reading differs, stop.
9. **Check** that an exact-SHA Gate-2 record for the migration is in the Execution Log: the owner's own, or one marked DELEGATED naming this contract, the migration's SHA-256, Primary `vrvtsxexkiiiivlkdxzp` and the owner's instructions under which it is taken. If absent, write it only when Step 8 passed and those instructions cover a migration that drops no table or column and deletes or rewrites no business row; otherwise stop after Step 8 and present the Gate-2 package.
10. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261111150000_a_retention_period_changes_only_with_step_up_and_a_record`. If it is absent and Step 9 is recorded:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts and the triggers of `document_retention_policies`.
   - On an exact match, prove the transmitted text's md5 server-side, then apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row, its stored statement md5 equal to the file's, and no existing target version.
   - Read fresh: the ledger, the function surface and all ten structural surfaces; the triggers of `document_retention_policies`; both functions' `md5(prosrc)`, security mode and ACL; the new code; the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
11. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with the client RPC figure unchanged.
   - Confirm that `supabase/tests` holds 164 files whose literal `plan(N)` values sum to 3101, then set `Suite **164 files / 3101 assertions**`. If either differs, stop.
   - In each of the two rows RET-3 and RET-4 of the register, replace the text `` | 🛡 | **FIXED 2026-11-11 locally (SPEC-304, `20261111150000`); Primary deployment pending.** `` with `` | ✅ | **✅ FIXED 2026-11-11 (SPEC-304, `20261111150000`), DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-304; the fresh Primary ledger, functions and structure equal local.** `` (each span's one leading and one trailing space are delimiters, not text). Change nothing else in the register.
   - Regenerate `ai-map.json` and `repository-index.md` (stored LF) with the canonical generators, and confirm the API-contract generator's output is identical to `MASTER_API_CONTRACT.md`.
   - Set the Runtime Checkpoint to DONE, append the Execution Log, and commit the implementation once; the pre-commit Gate must admit it.

   If Primary is unproven, stop.
12. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `-Finish` through `scripts/run_timed.ps1`, watched by `scripts/watch_run.ps1`, and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, in the Complete commit: transition to Complete, tick the Acceptance Criteria and the Review Gate, clear `Active Change Request`, set `Last Completed` from Notes, leave `Next capability` and `Current Module` unchanged, and regenerate `ai-map.json` and `repository-index.md` LF.
   - Bind the exact candidate with `-Gate -BindCandidate`. Publication and promotion follow the native release path separately.

## Acceptance Criteria

- [ ] The migration is the frozen bytes; `check: blob supabase/migrations/20261111150000_a_retention_period_changes_only_with_step_up_and_a_record.sql 5fb9f69fe762979395ecbe04d90e1f9b59ee6db3`
- [ ] Test 164 is the frozen bytes; `check: blob supabase/tests/164_a_retention_period_changes_only_with_step_up_and_a_record_test.sql 494d6a07c911412116bfcb652ad1b8533659782b`
- [ ] The MEAS-2 inventory names fourteen tables; `check: has supabase/tests/10_grant_model_test.sql "exactly these FOURTEEN tables"`
- [ ] The smoke count includes the new code; `check: has scripts/verify_database.sql "expected 626 catalog_values"`
- [ ] Canon 27 registers the new code; `check: has _ORVION_CANONICAL/27_event_catalog.md "## document_retention_policy_changed"`
- [ ] The disposition record carries `document_retention_policies` AUDITED / ADVERSARIAL and coverage 50 of 78; `check: blob reports/master/MASTER_SURFACE_DISPOSITION.md 163277642499317f9c4d852b76e7dd8b3f12afb8`
- [ ] RET-3 and RET-4 are fixed and deployed in the register; `check: has reports/master/MASTER_GAP_REGISTER.md "DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-304"`
- [ ] The manifest suite figure equals the files; `check: has _ORVION_CANONICAL/manifest.md "Suite **164 files / 3101 assertions**"`
- [ ] Native evaluator remains exact; `check: same scripts/check_agent_continuity.ps1 @53146b35901cade4cc436a1d34a9cd9c0601b651`
- [ ] The retention migration remains exact; `check: same supabase/migrations/202607060500_retention_becomes_a_policy_per_document_type.sql @53146b35901cade4cc436a1d34a9cd9c0601b651`
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write, after a recorded Step 8 readiness gate and Step 9 Gate-2 record; Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] Mutants M1–M4 are each killed with installation proven and the restored shape read, and the causal negative is recorded.

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

After actual native Finish and truthful Review, synchronize only this contract and the declared manifest/discovery paths to Complete. Set `Last Completed: **SPEC-304: Batch 6 Slice 49 — a retention period changes only with step-up and a record (RET-3, RET-4), deployed to Primary; native verification and Review complete. Publication/promotion remain separately governed.**` and regenerate discovery. `Next capability` and `Current Module` stay unchanged: the selector names the next slice. Candidate binding follows Complete and is never a pre-Complete criterion.

Exact baseline 53146b35901cade4cc436a1d34a9cd9c0601b651 and source anchors:

| Path | Baseline Git blob |
| --- | --- |
| `supabase/tests/10_grant_model_test.sql` | `518de71a30d557ae4737618fa3a3ecaf47476b08` |
| `scripts/verify_database.sql` | `58acd3d7755600acf8b1411d31b18a70e8a1f3f3` |
| `_ORVION_CANONICAL/27_event_catalog.md` | `c3fd59a12f850ac1058121f01126ac526a4982c2` |
| `reports/master/MASTER_GAP_REGISTER.md` | `8370b1069a7ce849ce0b4d078c60a7966f0fa98e` |
| `reports/master/MASTER_SURFACE_DISPOSITION.md` | `bbd4b7f10e22b0eab2e6f1a844ea99a881f77160` |

Selection sources: native AGENTS.md, CR_LIFECYCLE.md, ENGINEERING_METHOD.md and SPEC-301 at 53146b35901cade4cc436a1d34a9cd9c0601b651; the owner's instructions of 2026-11-08 and 2026-11-11 (recorded outside this repository). This is the one Draft for this surface, finalized after the adversarial review and the evidence refresh its Draft Assurance records; correctness remains native and independent.
