# Change Request — SPEC-231

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Make a document version's retention clock (`uploaded_at`) server-derived on INSERT and immutable on UPDATE at the `public.document_versions` table door, make a version's object key (`storage_path`) unique, and record `document_versions` as audited.

## Business Reason

Batch 6 Slice 29 selected `document_versions` live at Exposure 9, coverage 60; `lead_assignments` was runner-up at 9/66.

- **The intended rule.** A superseded version becomes a destruction candidate once `uploaded_at + retention_days` has passed: `app.reconcile_document_storage` records it and `app.claim_storage_actions` hands it to the storage executor, whose `object_deleted` resolution removes the metadata while the executor destroys the bytes. The period is the tenant's legal setting (canon 31: counsel-supplied, per document type), and setting it costs MANAGE_TENANT_SETTINGS through `document_retention_policies`' RLS. The current version is never eligible at any age. DOC-3 (`202607054400`) made a version's identity derived and immutable: `version_number`, `storage_path` and `uploaded_by` are computed by `app.enforce_document_version_integrity` and frozen on UPDATE. No RPC writes `uploaded_at`; all three creating RPCs take the column default.
- **DOC-7 (Medium, reproduced, latent).** Measured on the local stack at `669d656`, in rolled-back transactions:
  - An `employee` held CREATE_DOCUMENT_VERSION and not MANAGE_TENANT_SETTINGS. It saw both versions of the owner's supplier contract; v1 was superseded. A 3650-day `contract` policy was active, and the employee's UPDATE of it changed 0 rows.
  - The employee UPDATEd v1's `uploaded_at` to 2000-01-01. The next reconcile recorded it, the executor claimed it and `app.platform_resolve_storage_finding(…, 'object_deleted')` removed it. Nothing recorded the backdate.
  - Forward-dating a version the platform had aged 4000 days to 2999-01-01 took it off the claim list: the effect of a legal hold without MANAGE_TENANT_SETTINGS.
  - A direct INSERT kept a caller-supplied `uploaded_at` of 2000-01-01.
  - The same backdate landed at `aal1`, where both doors accept CREATE_DOCUMENT_VERSION.
- **DOC-8 (Low, reproduced, latent).** `version_number` is `max + 1` read under READ COMMITTED, and nothing makes it or the key unique. With the owner's `app.add_document_version` held open, an employee's direct INSERT of a non-current version committed first. Both rows became version 2 at one `storage_path`: the owner's current version and the employee's superseded one. `documents_write_own_tenant` then authorizes either row's upload to that one object, and retention of the superseded twin deletes the object the current version points at. Two concurrent RPC calls were already serialised by `document_versions_one_current_idx`.
- **Exposure.** Primary `vrvtsxexkiiiivlkdxzp` holds 232 migrations (latest `20260927130000`), 0 tenants, 0 document versions, 0 duplicate storage paths and 0 retention policies (read-only, 2026-09-27). RET-1 keeps retention unseeded until counsel supplies periods, so both findings are latent until the first tenant configures one.
- **Why these are not existing findings.** DOC-3 froze the other identity columns; `uploaded_at` became load-bearing later, when `202607054900` measured retention from it. DOC-4 (born under a hold), DOC-5 (the pointer) and DOC-6 (retyping) are `documents` rows. RET-1 and RET-2 are owner and business decisions about periods and lapsed tenants. No register row names the retention clock or the object key's uniqueness.
- **The repair** adds two lines to DOC-3's own trigger (derive `uploaded_at := now()` on a signed-in INSERT; add `uploaded_at` to the frozen identity list) and one unique index on `storage_path`. The session-less platform path, the permission charged and `is_current` are unchanged.

## Risks

- **Freezing the clock could stop ordinary document work.** Mitigated: no RPC writes `uploaded_at`, and the only UPDATE any RPC makes is `app.add_document_version`'s demotion of `is_current`, which stays mutable. In the prototype, upload, versioning, retention, the legal hold and every HTTP suite passed unchanged, including `verify_storage_end_to_end.ps1`.
- **A unique index could refuse an existing row or a legitimate write.** Mitigated: Primary holds 0 versions. The loser of a race is the only new refusal, and two concurrent RPC calls were already refused. The session-less path derives the same key, and no test fixture shares one.
- **Primary deployment replaces one function body and adds one index in production.** It requires separate exact-byte owner authorization (Gate 2) after the local proof; this contract's approval does not authorize it.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-231-document-version-clock-and-object.md`
- `supabase/migrations/20260927140000_a_document_version_owns_its_clock_and_its_object.sql`
- `supabase/tests/135_document_version_clock_and_object_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607054400_document_write_integrity.sql`
- `supabase/migrations/202607058500_paying_for_your_plan_is_not_a_plan_feature.sql`
- `supabase/migrations/202607054900_document_retention_and_storage_reconciliation.sql`
- `supabase/migrations/202607060500_retention_becomes_a_policy_per_document_type.sql`
- `supabase/migrations/20260909180403_a_legal_hold_always_overrides_retention.sql`
- `supabase/migrations/20260924140000_document_door_parity.sql`
- `supabase/tests/46_document_write_integrity_test.sql`
- `supabase/tests/49_document_retention_test.sql`
- `supabase/tests/97_retention_policy_per_document_type_test.sql`
- `supabase/tests/116_document_legal_hold_retention_override_test.sql`
- `supabase/tests/122_document_door_parity_test.sql`
- `_ORVION_CANONICAL/31_schema_draft.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `scripts/verify_database.sql`
- `scripts/verify_storage_end_to_end.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/31_schema_draft.md` (`document_versions`, `document_retention_policies`)
- `supabase/migrations/202607054400_document_write_integrity.sql` (DOC-1/DOC-3) and `202607058500_…` (LIC-3's current trigger body)
- Current local `public.document_versions` grants, `scope_isolation`, its four triggers and five indexes; `app.enforce_document_version_integrity`, `app.add_document_version`, `app.upload_document`, `app.upload_subscription_payment_proof`, `app.reconcile_document_storage`, `app.claim_storage_actions`, `app.platform_resolve_storage_finding`; the `storage.objects` policies
- `reports/master/MASTER_SURFACE_DISPOSITION.md` (`documents`, `document_versions`, Coverage); `reports/master/MASTER_GAP_REGISTER.md` (DOC-1/DOC-3, DOC-4, DOC-5, DOC-6, RET-1)

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

- `pwsh -NoProfile -File scripts/verify_storage_end_to_end.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A signed-in INSERT's `uploaded_at` is derived as `now()`, and an UPDATE of `uploaded_at` is refused with `42501` | the PostgREST table door; `app.upload_document`, `app.add_document_version`, `app.upload_subscription_payment_proof`; `document_versions.scope_isolation`; the other three triggers | VERIFY | The prototype was applied as a real migration on a clean reset in a scratch worktree at `669d656`: migration SHA-256 `26eb722c5706a75d813bcee1aa0830d61cc0b848ab27f92c25510eb2fbfca595`, test SHA-256 `e1cd9c19efbb5022689c2d2064af86becbe9abbe97100ceae7dd699756928595`. Refused with `42501` `a document version's identity is immutable: add a new version instead of rewriting one`: the employee's backdate and forward-date, including at `aal1`. A backdated INSERT is born at `now()`. Still landed: all three creating RPCs, the demotion UPDATE of `is_current`, and the session-less platform write of the clock. |
| `storage_path` is unique (`document_versions_storage_path_idx`) | `documents_read_own_tenant` and `documents_write_own_tenant` on `storage.objects`; `app.reconcile_document_storage`; `app.claim_storage_actions`; `app.platform_resolve_storage_finding` | VERIFY | Every consumer matches on `storage_path`; each now names at most one version. The race above ends in `23505` for the loser and one row per key. `verify_storage_end_to_end.ps1` uploads, reads and reconciles over HTTP and passed 60/0. |
| The retention pipeline | `document_retention_policies`; `app.suppress_held_retention_candidate`; legal hold | VERIFY | A version the platform aged 4000 days is still claimed under a 3650-day policy; a held document's versions are still suppressed; a disagreement between `is_current` and the pointer still fails closed. Tests 49, 97 and 116 pass unchanged. |
| Existing document tests | `28_…`, `46_…`, `47_…`, `49_…`, `52_…`, `60_…`, `97_…`, `116_…`, `122_…` | VERIFY | Every fixture that writes `uploaded_at` does so session-less, and none shares a key; all pass unchanged in the prototype's full suite. |
| Rows that already exist | Primary and local `public.document_versions` | VERIFY | The trigger judges only new writes and no row is rewritten. The index builds only if no key repeats: Primary held 0 versions and 0 duplicate keys on 2026-09-27 (read-only). |
| Suite, smoke and every HTTP door | full pgTAP; `scripts/verify_database.sql`; all six HTTP suites | VERIFY | On the prototype stack, in `-Finish`'s order: pgTAP Pass A 135 files / 2428 assertions PASS (2408 existing assertions unchanged, plus 20 new). HTTP suites: 33 + 40 + 74 + 122 + 120 + 60 = 449 passed, 0 failed. Pass B without reset: 135 / 2428 PASS. Smoke: `ALL CHECKS PASSED`, exit 0. |
| The generated API surface | `MASTER_API_CONTRACT.md`; `check_database_parity_evidence.ps1` Check L3 | VERIFY | No RPC, view or table changes. `check_database_parity.ps1` on the prototype stack reports the contract matching the live surface (79 RPC endpoints, 8 views, 73 tables). It is regenerated in Step 7, and any difference is recorded. |
| Measured state that moves | manifest (`Live state`, suite figure, Batch 6 coverage, Last Completed, Active pointer); `primary-ledger-evidence.json`; `ai-map.json`; Checks 5, 7, 15, 19, 22, 24 | WRITE | 232 → 233 migrations, latest `20260927140000`; 134 → 135 files / 2408 → 2428 assertions; coverage 29 → 30 of 77. Primary values are written only from fresh post-deploy readings. The manifest is 6664 of its 7000-character budget, and Step 7 keeps each moved line within its current length or trims `Last Completed`. |
| Findings and disposition | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 2, 11, 16, 21, 22, 25 | WRITE | Two new rows: DOC-7 and DOC-8, each with Owner Decision `—`, so Check 25 adds nothing to the open-decision line. DOC-1/DOC-3, DOC-4, DOC-5, DOC-6, RET-1 and every other row are unchanged. Only the `document_versions` disposition row changes, to `AUDITED` / `ADVERSARIAL` with findings DOC-7 and DOC-8. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused test, pgTAP A/B, the declared HTTP suite, smoke and in-file mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| DOC-7, DOC-8 and the `document_versions` disposition accurately describe local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite figure equals the files and plan sum | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| Manifest Batch 6 coverage equals the disposition record | BEFORE_COMPLETION | Step 3 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: DOC-3's `app.enforce_document_version_integrity()` on trigger `document_versions_enforce_integrity` (BEFORE INSERT OR UPDATE, SECURITY INVOKER, empty `search_path`, EXECUTE revoked from PUBLIC) already derives a version's identity on INSERT and freezes it on UPDATE. `uploaded_at` joins both lists, and nothing else in it changes. The repository's concurrency precedent (`104_…`: "serialised by the unique index, which cannot be raced by construction") owns DOC-8 with one unique index. The alternatives were rejected:
- a new trigger for the clock would be a second owner of the version's identity;
- locking the parent document inside the trigger to serialise `max + 1` adds a lock on every version write and still leaves the key's uniqueness unstated;
- a unique index on `(document_id, version_number)` states numbering, not the object key that storage, reconciliation and the executor match on.

Added Property: On any signed-in path, a new version's `uploaded_at` is the server's clock and no UPDATE can change it; and no two versions share a `storage_path`. The session-less platform path keeps its exemption, and `is_current` stays mutable for `app.add_document_version`.

Causal Negative: On the local stack at `669d656`, in rolled-back transactions, an `employee` without MANAGE_TENANT_SETTINGS backdated the owner's superseded contract version under a 3650-day policy, and the executor claimed and removed it; the same employee forward-dated a due version off the claim list. In a timed race, the employee's direct INSERT and the owner's `app.add_document_version` both committed version 2 at one `storage_path`.

Positive Test Design: As the employee at `aal2`: add a version by direct INSERT, and add one through `app.add_document_version` (which demotes the current version by UPDATE). Session-less: age a version's clock, after which the executor may claim it under the policy.

Negative Test Design: As the employee, the backdate of the owner's superseded version and the forward-date of a due version are refused with `42501` `a document version's identity is immutable: add a new version instead of rewriting one`. A backdated INSERT is born at `now()`, the owner's version keeps its real upload time, and the tenant has no destruction candidate under its policy. A second row at an existing key is refused with `23505`, and the index is present. The employee's UPDATE of another tenant's version changes nothing.

Non-Empty Population Obligation: The employee holds CREATE_DOCUMENT_VERSION and not MANAGE_TENANT_SETTINGS, sees both of the owner's versions, and cannot change the 3650-day policy. v1 is superseded (not current and not the pointer), so its age alone decides eligibility. The platform-aged v1 is claimable before the forward-date is attempted.

Mutation Obligation: Record `app.enforce_document_version_integrity`'s `pg_get_functiondef` md5, then open a savepoint, install the pre-repair definition and drop `document_versions_storage_path_idx`. Prove the md5 differs. As the employee, prove the backdate lands and makes the owner's version claimable, and prove a second row lands on an existing key. Roll back to the savepoint, then prove the md5 is identical, the index is present and no mutant backdate survived. A mutant whose installation is not proven is a harness error, never a killed mutant.

Post-Implementation Proof Obligation: Focused test, clean reset, pgTAP Pass A, the declared HTTP suite, pgTAP Pass B, smoke, the in-file mutation, generated artifacts, fresh Primary evidence, parity evidence, the Primary ledger check, repository consistency and `git diff --check`, all on the final bytes and through canonical `-Finish`.

## Implementation Steps

1. **Check** that `supabase/migrations/20260927140000_a_document_version_owns_its_clock_and_its_object.sql` is absent. If absent, create it LF with SHA-256 `26eb722c5706a75d813bcee1aa0830d61cc0b848ab27f92c25510eb2fbfca595`. It holds one `create or replace function app.enforce_document_version_integrity()`, whose body is LIC-3's (`202607058500`) plus `new.uploaded_at := now();` (with a one-line DOC-7 comment) on a signed-in INSERT and `uploaded_at` in the frozen identity list, with the derivation comment's "three columns" now "four columns", then `revoke execute ... from public`, then `create unique index document_versions_storage_path_idx on public.document_versions (storage_path)`. The security mode stays INVOKER and the `search_path` stays empty. It changes no trigger, policy, grant, RPC or other function. If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/135_document_version_clock_and_object_test.sql` is absent. If absent, create it LF with SHA-256 `e1cd9c19efbb5022689c2d2064af86becbe9abbe97100ceae7dd699756928595`. It is one transaction-rolled-back pgTAP file with `select plan(20);`. Its first line is `-- ATTACK-CLASSES: PRIVILEGE DOOR TENANT BUSINESS CONCURRENCY INPUT AUTH=N/A STATE=N/A REPLAY=N/A OBSERVABILITY=N/A`, and its header cites SPEC-231 and states each `N/A` reason. It implements:
   - the Non-Empty Population Obligation (1-4);
   - DOC-7's Negative and Positive Test Design (5-13);
   - DOC-8 (14-15) and the tenant refusal (16);
   - the Mutation Obligation (17-20).

   If the target exists with different bytes, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` contains `| DOC-7 |`. If absent:
   - Add a dated Slice 29 freshness entry and demote the previous entry to `Previously:`.
   - Append two rows after `| TASK-4 |`: **DOC-7** (Category `retention · data integrity`, Sev `Medium`) and **DOC-8** (Category `concurrency · data integrity`, Sev `Low`), each Req/Opt `R`, Batch `6`, Mig `A`, Cert `📋`, Owner Decision `—`, Source `SPEC-231-document-version-clock-and-object`, dates `09-27`. Each Status reads `FIXED locally by SPEC-231 (`20260927140000`), pending Primary deployment` and states:
     - the reproduction and consequence above;
     - latent exposure (0 versions and 0 retention policies on Primary; RET-1);
     - why it is not DOC-3, DOC-4, DOC-5, DOC-6 or RET-1;
     - that the repair reuses DOC-3's trigger (DOC-7) or adds one unique index (DOC-8);
     - that it is pinned by `135_...`.
   - Change no other row.

   Then check whether `reports/master/MASTER_SURFACE_DISPOSITION.md`'s `document_versions` row reads `NOT-RECORDED`. If so:
   - Set it to `AUDITED` / `ADVERSARIAL` / `SPEC-231-document-version-clock-and-object` / `DOC-7, DOC-8`. Its Next cell names `135_document_version_clock_and_object_test.sql` and what it proves, and states the swept non-defects:
     - `file_name`, `file_type_code` and `file_size` stay editable by an actor who can already add a version, as SPEC-216 ruled for a document's title; the bytes and identity are frozen and nothing server-side reads them;
     - a disagreement between `is_current` and the document's pointer only keeps a version longer (retention fails closed at claim and at resolve) and clears on the next version;
     - both doors accept CREATE_DOCUMENT_VERSION at `aal1`, so step-up is not this surface's control;
     - a direct INSERT emits no `document_version_created`, CAMP-4's shape, and nothing outside the event registry reads it;
     - the parent document's type, hold, pointer and archive state, the retention policy and the findings table each refused the employee;
     - tenant isolation held, and DELETE has no grant.
   - Update Coverage to `30 of 77 recorded · 11 AUDITED · 16 AUDITED-OPEN · 3 PARTIAL · 0 EXEMPT · 47 NOT-RECORDED` and `All 30 recorded surfaces`.
   - Add a dated freshness entry and demote the previous one to `Previously:`.
   - Change no other row.

   If either target already carries different content, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 hashes:
   - a clean local reset and the focused test;
   - pgTAP Pass A, the declared HTTP suite, then pgTAP Pass B without reset;
   - `scripts/verify_database.sql` and the plan sum;
   - the in-file mutation evidence;
   - the API-contract and map generators;
   - the scope check, `git diff --check` and repository consistency.

   Treat only undeployed Primary, manifest and parity drift as expected at this boundary. Read a fresh Primary baseline, read-only:
   - the full ordered ledger;
   - the function and structural surfaces;
   - the tenant, version, duplicate-key and retention-policy counts;
   - the absence of the target migration and of the index;
   - the trigger function's current definition md5.

   Record the predicted structural delta.
5. **Check** that exact owner authorization for the migration and Test-135 SHA-256 values is recorded in the Execution Log. If absent, stop after Step 4 and present:
   - the current HEAD;
   - the exact 64-character hashes;
   - the fresh Primary baseline and the predicted delta;
   - the exact Primary write requested.

   Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20260927140000_a_document_version_owns_its_clock_and_its_object`. If it is absent and deployment is separately authorized:
   - Immediately re-read: HEAD; both hashes; the project URL; the full ordered ledger; target and index absence; the version and duplicate-key counts; and the function's pre-repair md5.
   - On an exact match, apply only the authorized migration through the Primary connector. If the connector assigns a temporary version, normalize only its newly inserted ledger row.
   - Read fresh: the ledger, the function surface and all ten structural surfaces, the function's definition md5, security mode, `search_path` and EXECUTE ACL, the trigger's timing and enabled state, and the index's definition.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`:
     - Set the `Live state` migration count, latest version, ledger and surface hashes and counts from the same readings.
     - Set the suite figure to `Suite **135 files / 2428 assertions**`, after confirming `supabase/tests` holds 135 files whose literal `plan(N)` values sum to 2428. If either differs, stop.
     - Change the Batch 6 line's `**29 of 77 surfaces have a recorded audit disposition**, all twenty-nine at` to `**30 of 77 surfaces have a recorded audit disposition**, all thirty at`, only after Step 3 set Coverage to `30 of 77 recorded`.
     - Set `Last Completed` to Slice 29 / DOC-7 / DOC-8 / SPEC-231, trimming it so the manifest stays within 7000 characters.
   - Mark DOC-7 and DOC-8 `FIXED` and `DEPLOYED` in the register and change their Cert to `✅`.
   - Regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` (stored LF) with the canonical generators, never by hand.
   - Run `check_primary_ledger.ps1`, `check_database_parity_evidence.ps1`, repository consistency and `git diff --check`.

   If Primary is unproven, stop.
8. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, set Runtime Checkpoint DONE, transition Complete, set `Next capability` to Batch 6 Slice 30 ranked by `scripts/batch6_select_target.ps1`, clear `Active Change Request` and regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate and require exact-SHA candidate CI. Promote the same accepted SHA, run `-Certify` for `REMOTE_CERTIFY: READY`, verify synchronized clean refs and remove permitted scratch files.

   Do not start Slice 30.

## Acceptance Criteria

- [x] On every signed-in path, a document version's `uploaded_at` is the server's clock: the employee's backdate and forward-date are pinned to `42501` `a document version's identity is immutable: add a new version instead of rewriting one`, a backdated INSERT is born at `now()`, and the owner's superseded version is no destruction candidate under the tenant's policy.
- [x] No two versions share a `storage_path`: a second row at an existing key is refused with `23505`, and `document_versions_storage_path_idx` is unique on that column alone.
- [x] With the pre-repair trigger installed and the index dropped in a savepoint, the employee's backdate makes the owner's version claimable and a second row lands on one key; the restored trigger is byte-identical, the index is back and no mutant backdate survives.
- [x] Upload, versioning (including the demotion of `is_current`), the session-less platform write of the clock, retention under a policy, the legal hold, every RPC and every policy keep their behaviour; `verify_storage_end_to_end.ps1` passes.
- [x] DOC-7 (Medium) and DOC-8 (Low) are registered `FIXED` / `DEPLOYED`. `document_versions` is `AUDITED` / `ADVERSARIAL` with findings DOC-7 and DOC-8. Coverage reads 30 of 77 in both the disposition record and the manifest. Every other row is unchanged.
- [x] The migration and Test 135 match their authorized SHA-256 values. Primary, the recorded evidence, the manifest (233 migrations; 135 files / 2428 assertions), the API contract and `ai-map.json` agree.
- [x] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and no business-data write, and Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [x] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-09-27 — Owner approval

Owner approved the exact Draft SHA `bb1ac3cfe2c866fa6b1ec89c36eca7085f33c5e6` and the frozen nine-path Write Scope, with DOC-7 and DOC-8 as FIX NOW under the approved design. A read-only evaluation of the committed Draft returned `APPROVAL_EVIDENCE: PASS` (profiles DATABASE, REPOSITORY). Two mutated copies returned FAIL (a gate inside a red window) and INDETERMINATE (Mutation Obligation removed). Pre-approval revalidation:
- HEAD was the Draft SHA and the tree was clean;
- `origin/main` and `origin/orvion-preflight` were at `669d656`;
- the prototype migration and Test 135 hash to the frozen values;
- the local stack is back at 232 migrations after the prototype.

The approval is bound to migration SHA-256 `26eb722c5706a75d813bcee1aa0830d61cc0b848ab27f92c25510eb2fbfca595` and Test-135 SHA-256 `e1cd9c19efbb5022689c2d2064af86becbe9abbe97100ceae7dd699756928595`. DOC-7 and DOC-8 are the only new findings this contract owns; no other document finding and not RET-1 is absorbed, and no unrelated register row changes.

The owner asked for two review hypotheses to be proved or falsified before implementation; both hold:
1. `storage_path` is object identity. Its only producers are `app.upload_document`, `app.add_document_version` and `app.upload_subscription_payment_proof`, all INVOKER and all leaving the key to the trigger's `tenant/document/version` derivation (canon R1 in `202607054600`, "the single source of a document version's object key" in `202607054400`). No copy, move, restore or re-point path exists, and the `storage.objects` policies allow INSERT and SELECT only. Every consumer treats one key as one version: the storage executor's `remove([storage_path])`, `app.claim_storage_actions`, and the findings identity key `(tenant_id, finding_type_code, storage_path)`, which can link only one version per path.
2. Stamping `uploaded_at` on signed-in inserts leaves the platform path unchanged. The trigger's session-less branch returns before the new line, and `auth.uid()` is null for `postgres` and for a `service_role` JWT, which carries no `sub`. `verify_storage_end_to_end.ps1` writes historical `uploaded_at` values as the platform (its version inserts at lines 121 and 236) and passed 60/0 on the prototype. No signed-in producer accepts a timestamp, no SECURITY DEFINER function inserts a version, and neither canon nor the integration catalog defines a document import or backfill path.

Approval authorizes Approve, In Progress, Steps 1-4 and local proof. It does not authorize a Primary write, which needs separate exact-byte authorization at Gate 2.

### 2026-09-27 — Execution started

The approved nine-path contract entered In Progress at `33a23e7`. Resume Step 1. Local implementation and proof through the Step 4 pre-deploy readiness gate are authorized; Primary deployment remains separately gated at Step 5.

### 2026-09-27 — Steps 1-3 executed

- Step 1: Applied. `supabase/migrations/20260927140000_a_document_version_owns_its_clock_and_its_object.sql` was created LF, SHA-256 `26eb722c5706a75d813bcee1aa0830d61cc0b848ab27f92c25510eb2fbfca595`, exactly the value this step names.
- Step 2: Applied. `supabase/tests/135_document_version_clock_and_object_test.sql` was created LF, SHA-256 `e1cd9c19efbb5022689c2d2064af86becbe9abbe97100ceae7dd699756928595`, `plan(20)`, exactly the value this step names.
- Step 3: Applied.
  - Register: a Slice 29 freshness entry was added, and the Slice 28 entry was demoted to `Previously:`. DOC-7 (Medium) and DOC-8 (Low) were appended after `| TASK-4 |`, each `FIXED locally by SPEC-231`, pending Primary deployment, Cert `📋`, Owner Decision `—`. No other row changed, including DOC-1/DOC-3, DOC-4, DOC-5, DOC-6 and RET-1.
  - Disposition: `document_versions` was set to `AUDITED` / `ADVERSARIAL` / `SPEC-231-document-version-clock-and-object` / `DOC-7, DOC-8`. Coverage reads `30 of 77 recorded · 11 AUDITED · 16 AUDITED-OPEN · 3 PARTIAL · 0 EXEMPT · 47 NOT-RECORDED` and `All 30 recorded surfaces`. A freshness entry was added, and no other row changed.
  - Both code files are byte-identical to the prototype that was checked before freezing.

### 2026-09-27 — Pre-deploy readiness gate

On HEAD `b01f83f`, with Steps 1-3 in the working tree:
- Clean reset: exit 0, 233 migrations through `20260927140000`.
- Focused Test 135: 20/20.
- pgTAP Pass A: `Files=135, Tests=2428, Result: PASS`.
- `verify_storage_end_to_end.ps1`: 60 passed, 0 failed.
- pgTAP Pass B without reset: `Files=135, Tests=2428, Result: PASS`.
- `scripts/verify_database.sql`: `ALL CHECKS PASSED`, exit 0.
- Plan sum: 2428 over 135 files.

Mutation (Test 135, assertions 17-20): the pre-repair trigger was installed and `document_versions_storage_path_idx` dropped in a savepoint, and the trigger's md5 was proven to differ. The employee's backdate then landed and made the owner's superseded version claimable under the ten-year policy, and a second row landed on an existing key. After rollback to the savepoint, the trigger was md5-identical to the repaired definition, the index was back and no mutant backdate survived. On the unrepaired stack at `669d656`, the same file failed exactly the repair-owned assertions 5, 7, 8, 9, 12, 14 and 15, passed the controls, and could not install its mutation because the index it drops did not exist.

Generators:
- `MASTER_API_CONTRACT.md` matches the live surface of this stack (79 endpoints, 8 views, 73 tables), so it is left unchanged.
- `ai-map.json` is regenerated in Step 7, once the manifest moves.

Checks on the working tree:
- `git diff --check` exited 0. The changed paths are the CR, the migration, Test 135, the register and the disposition record, all inside the frozen nine.
- Repository consistency found 6 issues, all expected at this boundary. Three come from the undeployed migration (manifest migration count, latest version and ledger fingerprint `c641ed4f9faf6b8acb4c1342d311840d`). Two are the suite figures (134/2408 vs 135/2428), which move in Step 7. The last is ledger evidence lacking `20260927140000`.

Under these reds the Gate blocks a commit, so these steps stay uncommitted until deployment, and `-Finish`, `LOCAL_CERTIFY` and candidate publication follow in Steps 7-8, as SPEC-230 did.

Local candidate surfaces (`scripts/check_database_parity.ps1`):
- ledger 233 / `c641ed4f9faf6b8acb4c1342d311840d`;
- functions `25c5bce0b252c36d1cb1f04042f0d3a3` / 309;
- indexes `f1135ab423db8ad5d756a2b413aebfc3` / 295;
- triggers, policies, constraints, grants, columns, views, status transitions and RLS flags identical to the recorded Primary values;
- combined `5a0247339f2a182952d3189e68d84edf` / 3059.

The repaired function's `pg_get_functiondef` md5 is `c77b0aea4878c7be688526d52b69bdc8`. It is SECURITY INVOKER, with `search_path` empty and ACL `{postgres=X/postgres}`; `document_versions_enforce_integrity` is `tgtype` 23, enabled `O`; the index is `CREATE UNIQUE INDEX document_versions_storage_path_idx ON public.document_versions USING btree (storage_path)`.

Fresh Primary `vrvtsxexkiiiivlkdxzp` baseline, read-only, 2026-09-27, through `scripts/parity_surface.sql`'s own queries:
- ledger 232 / `4d034c995b053b3d7eb8ed2d8455a363`, latest `20260927130000`, target absent, index absent;
- functions `366a22adb93c1acd53406064b927a908` / 309; indexes `3973f9c9dab7d4ca8cfc4b3466bd859c` / 294; combined `b6719372293723a6f1ce9cdfcc6c6d04` / 3058; all ten categories equal to the recorded evidence;
- 0 tenants, 0 document versions, 0 duplicate storage paths, 0 retention policies;
- the function md5 is `5dc38272dd7eb47584384f8a4171345b` (pre-repair). It is INVOKER, with `search_path` empty and ACL `{postgres=X/postgres}`. `document_versions_enforce_integrity` is `tgtype` 23, enabled `O`.

Predicted delta:
- ledger → 233 / `c641ed4f9faf6b8acb4c1342d311840d`;
- functions → `25c5bce0b252c36d1cb1f04042f0d3a3` / 309;
- function md5 → `c77b0aea4878c7be688526d52b69bdc8`;
- indexes → `f1135ab423db8ad5d756a2b413aebfc3` / 295;
- the eight other categories unchanged;
- combined → `5a0247339f2a182952d3189e68d84edf` / 3059.

Primary deployment awaits separate exact-byte owner authorization (Step 5). Secondary was not contacted.

### 2026-09-27 — Authorized Primary deployment and reconciliation

**Authorization.** The owner authorized one Primary operation on `vrvtsxexkiiiivlkdxzp` (Step 5): `supabase/migrations/20260927140000_a_document_version_owns_its_clock_and_its_object.sql`, SHA-256 `26eb722c5706a75d813bcee1aa0830d61cc0b848ab27f92c25510eb2fbfca595`, bound to Test-135 SHA-256 `e1cd9c19efbb5022689c2d2064af86becbe9abbe97100ceae7dd699756928595`, with the conditions presented at Gate 2. It authorizes no business-data, policy, grant, trigger or other function write.

**Recheck immediately before writing.** Everything matched exactly:
- HEAD `b01f83f`, with SPEC-231 In Progress; both hashes; only in-scope paths changed.
- The connector URL names `vrvtsxexkiiiivlkdxzp`.
- Primary: 232 / `4d034c995b053b3d7eb8ed2d8455a363`, latest `20260927130000`, target and index absent. Function md5 `5dc38272dd7eb47584384f8a4171345b`, SECURITY INVOKER, `search_path` empty; `document_versions_enforce_integrity` 23/`O`. 0 tenants, 0 versions, 0 duplicate keys, 0 retention policies.

**Deployment (Step 6).** Only that migration was applied, through the Primary connector. The connector created exactly one new row, with temporary version `20260927171236`. Its stored statement (5990 bytes, md5 `abfbf7bdd7a0b980725478da54a5f43d`) equals the migration file. A guarded update then renamed only that row to `20260927140000`: there was no existing `20260927140000`, 1 row was updated, and 0 temporary rows remain. There was no business-data write, the exploit was not replayed on Primary, and Secondary was not contacted.

**Fresh postwrite readings**, every value equal to the local prediction:
- ledger 233 / `c641ed4f9faf6b8acb4c1342d311840d`, with the target exactly once;
- functions `25c5bce0b252c36d1cb1f04042f0d3a3`/309 and indexes `f1135ab423db8ad5d756a2b413aebfc3`/295;
- triggers, policies, constraints, grants, columns, views, status transitions and RLS flags unchanged;
- combined `5a0247339f2a182952d3189e68d84edf`/3059.

**Direct inspection.** `app.enforce_document_version_integrity()` has `pg_get_functiondef` md5 `c77b0aea4878c7be688526d52b69bdc8`, equal to local. It is SECURITY INVOKER with an empty `search_path` and ACL `{postgres=X/postgres}`, and it is not executable by anon or authenticated. `document_versions_enforce_integrity` is `tgtype` 23, enabled `O`. `document_versions_storage_path_idx` is `CREATE UNIQUE INDEX … USING btree (storage_path)`. 0 tenants, 0 versions.

**Reconciliation (Step 7).** Every value below comes from those readings:
- `reports/evidence/primary-ledger-evidence.json` holds the Primary-read ordered ledger of 233 entries, verified to hash to the fingerprint, and the new function and structural hashes.
- Manifest:
  - `Live state` moved to 233 / `20260927140000` / `c641ed4f…` / `25c5bce0…` (309) / `5a024733…` (3,059).
  - The suite figure moved to 135 files / 2428 assertions, after measuring 135 files with a plan sum of 2428.
  - The Batch 6 line moved to `**30 of 77 surfaces have a recorded audit disposition**, all thirty at`, after Step 3 set Coverage to 30 of 77.
  - `Last Completed` moved to Slice 29 / DOC-7 / DOC-8 / SPEC-231.
  - The manifest is 6659 characters.
- DOC-7 and DOC-8 are marked `FIXED` / `DEPLOYED`, with Cert `✅`. No other register row changed.
- `MASTER_API_CONTRACT.md` regenerated byte-identical, so it is unchanged. `ai-map.json` was regenerated and stored LF.

`check_primary_ledger.ps1` CLEAN, `check_database_parity_evidence.ps1` CLEAN, `check_repository_consistency.ps1` exit 0 and `git diff --check` exit 0. The Runtime Checkpoint names DONE so canonical `-Finish` can run in VERIFY mode. Status stays In Progress pending Review and the Complete transition.

### 2026-09-27 — Post-deploy local certification

Canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` ran on the clean committed execution HEAD `01ef83e` in VERIFY mode, with no telemetry opt-outs. It derived profiles DATABASE and REPOSITORY, passed every mandatory verification, then returned `LOCAL_CERTIFY: READY` on its first run:
- `npx supabase db reset`;
- `npx supabase test db` (Pass A);
- `scripts/verify_storage_end_to_end.ps1`;
- `npx supabase test db` (Pass B);
- `scripts/verify_database.sql`;
- `scripts/check_database_parity_evidence.ps1`;
- `scripts/check_repository_consistency.ps1`;
- `git diff --check`;
- `scripts/check_primary_ledger.ps1`.

Finish keeps only PASS lines. At the pre-deploy gate, the same committed migration and test bytes measured `Files=135, Tests=2428, Result: PASS` in both passes, 60/0 on the declared HTTP suite, and `ALL CHECKS PASSED`. Finish validated the recorded Primary evidence and did not contact Primary. The telemetry retry rule was never needed.

### 2026-09-27 — Independent Review of execution commit

Reviewed the committed execution HEAD `01ef83e` against the approved Draft `bb1ac3c` and the frozen nine-path Write Scope. The working tree was clean and the pre-commit Gate reported `ORVION: READY`. The range `669d656..01ef83e` changes eight paths, all inside the frozen nine, and nothing in Out of Scope. `MASTER_API_CONTRACT.md` regenerated byte-identical and is unchanged. The committed blobs hash to the authorized values: migration `26eb722c5706a75d813bcee1aa0830d61cc0b848ab27f92c25510eb2fbfca595`, Test 135 `e1cd9c19efbb5022689c2d2064af86becbe9abbe97100ceae7dd699756928595`.

Acceptance, re-checked against the committed bytes:
1. Test 135 assertions 5 and 12 refuse the employee's backdate of the owner's superseded version and forward-date of a due one, each with `42501` `a document version's identity is immutable: add a new version instead of rewriting one`. Assertion 7 reads a backdated INSERT born at `now()`, assertion 8 the owner's version at its real upload time, and assertion 9 no destruction candidate for the tenant under its ten-year policy.
2. Assertion 14 reads `document_versions_storage_path_idx` unique on `storage_path` alone, and assertion 15 refuses a second row on an existing key with `23505`.
3. Mutation assertions 17-20 install the pre-repair trigger and drop the index, with the md5 proven to differ. They watch the backdate make the owner's version claimable and a second row land on one key, then restore the trigger md5-identical with the index back and no mutant backdate surviving. On the unrepaired stack the same file failed exactly 5, 7, 8, 9, 12, 14 and 15.
4. Assertions 6, 10, 11 and 13 keep a table-door insert, the session-less write of the clock, retention under the policy and the RPC's demotion of `is_current`. Tests 46, 49, 97, 116 and 122 pass unchanged. No policy, trigger or RPC changed: on Primary the categories other than functions and indexes are unchanged, the function delta is this trigger alone and the index delta is the new index alone. The declared HTTP suite passes, and at the prototype all six passed (449/0).
5. The register diff adds only the Slice 29 freshness entry and the DOC-7 (Medium) and DOC-8 (Low) rows, both `FIXED` / `DEPLOYED`, Cert `✅`; every other row, including DOC-1/DOC-3, DOC-4, DOC-5, DOC-6 and RET-1, is byte-identical to `669d656`. The disposition diff changes only the `document_versions` row (`AUDITED` / `ADVERSARIAL` / DOC-7, DOC-8), Coverage and its freshness entry. Thirty rows are recorded, matching Coverage `30 of 77`, and the manifest reads `**30 of 77 surfaces have a recorded audit disposition**, all thirty at`.
6. Fresh Primary 233 / `c641ed4f9faf6b8acb4c1342d311840d`, functions `25c5bce0b252c36d1cb1f04042f0d3a3`/309, indexes `f1135ab423db8ad5d756a2b413aebfc3`/295 and combined `5a0247339f2a182952d3189e68d84edf`/3059 equal local. The function md5 `c77b0aea4878c7be688526d52b69bdc8` equals local. The recorded evidence, the manifest (`Suite **135 files / 2428 assertions**`), the contract and the LF `ai-map.json` agree, and `-Finish` is READY.
7. Primary received only the authorized migration plus the one guarded ledger-identity correction. There was no business-data write, the exploit was not replayed on Primary, and Secondary was never contacted.
8. No file outside Write Scope was created, modified or deleted.

Verdict: Confirmed Complete

Recommendation to human: Set Status to Complete

## Verification Notes

None yet.

Verdict: Confirmed Complete

## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created or deleted.
- [x] No section was added, removed or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

- **EARN IT.** Both findings were reproduced end to end against rules the repository already states: canon 31 measures retention from `uploaded_at` and gives its period to MANAGE_TENANT_SETTINGS; DOC-3 made a version's identity derived and immutable; `app.document_storage_path` makes the key the version's. DOC-7's consequence is irreversible destruction by the platform's own executor of a version the tenant's legal setting keeps, or the reverse, a hold without the hold's authority. DOC-8's is one object named by two versions, so destroying the superseded twin destroys the current file. No existing control owns either.
- **WORTH IT.** Two lines in the trigger that already owns version identity, and one index. No data reconciliation is needed (Primary has 0 versions). A reopen trigger was rejected because the event that exposes both, a tenant configuring its first retention policy, is a table write that no CR or check observes, and the consequence is irreversible. The residual cost is Gate 2 and one deployment.
- **Rejected alternatives:**
  - recording DOC-7 and DOC-8 OPEN until RET-1 is decided: nothing would fire when the first policy is configured;
  - freezing `is_current` or restricting it to demotion: its disagreement with the pointer already fails closed, can only keep a version longer, and the RPC needs the demotion;
  - freezing `file_name`, `file_type_code` and `file_size`: no server-side reader, and SPEC-216 ruled the same way for a document's title.
- **Untouched:** DOC-1/DOC-3, DOC-4, DOC-5, DOC-6, RET-1, RET-2, CAMP-4, STEPUP-1 and every other open finding. The registered worktree `owt/p2` is untouched.
