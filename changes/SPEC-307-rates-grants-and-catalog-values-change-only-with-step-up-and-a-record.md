# Change Request — SPEC-307

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Batch 6 Slice 51 makes exchange rates, user permission grants and tenant catalog values writable only with step-up, keeps a rate that recorded money cites and a catalog value in use fixed, and records every rate set and every move of a grant, so a password alone can no longer set the rate money is converted at, grant a permission or extend a platform-owned family, and no money, grant or catalog code changes meaning unrecorded (FX-5, FX-6, USR-3, RBAC-7, CAT-7, CAT-8, CAT-9).

## Business Reason

- **Selection.** `scripts/batch6_select_target.ps1` at `b44cad9`, on the live local catalog, ranks `exchange_rates` first (Exposure 6, coverage 66), then `user_permission_grants` (6/88) and `catalog_values` (6/102), all NOT-RECORDED. The owner's instruction of 2026-11-14 groups the selector's next surfaces in one contract per product; each surface keeps its own finding rows, migration, test and disposition row. The manifest's Next capability names that selector, never a copy of its result.
- **Why it matters.** Each table is written directly through its door: `authenticated` holds INSERT and UPDATE, and the write policy charges a permission through `app.has_permission` (`SET_EXCHANGE_RATE`, `MANAGE_PERMISSIONS`, `MANAGE_TENANT_SETTINGS`), never the step-up `app.authorize` charges every role `app.requires_mfa` binds. A rate is what `app.exchange_rate_as_of` and the money that cites it (booking items, payments, allocations, adjustments) convert at; `exchange_rate_adjustments` (append-only) is the designed correction path, and canon 27 registers `exchange_rate_set` (critical), which nothing emitted. A user grant moves `app.has_permission` (RBAC-5). A catalog value is what `app.enforce_catalog_codes` accepts on a tenant's rows; `catalog_types.ownership_type` names the 4 families open to tenants and the 67 the platform owns.
- **Measured at `b44cad9`** on the local stack, probe fixtures rolled back (one tenant with an owner, a ceo, a finance manager and an employee; another tenant; a rate cited by a booking item, a live grant, a supplier type used by a supplier):
  - **FX-5 (High).** A finance manager at `aal2` rewrote the cited rate from 48.5 to 99, and a ceo re-dated it a year back and turned its pair around; `app.exchange_rate_as_of` answered 99, `set_by` still named the first setter, and the tenant's events did not move.
  - **FX-6 (High).** A finance manager at `aal1` set a new rate. The table is a named member of STEPUP-1.
  - **USR-3 (High, its open half).** A ceo at `aal1` granted itself `VIEW_ADVANCED_DASHBOARDS` at the table door; SPEC-300 closed the placement half.
  - **RBAC-7 (High).** A ceo at `aal2` re-pointed a live grant from an employee to the finance manager, then to `MANAGE_PERMISSIONS`, then turned it into a deny; `app.emit_permission_change` compared only liveness, which stayed true, so nothing was recorded.
  - **CAT-7 (High).** An owner at `aal2` added values to the platform-owned families `payment_direction` and `booking_item_base_status`, which `app.enforce_catalog_codes` then accepts on the tenant's rows; another tenant value was written with `is_system = true`.
  - **CAT-8 (Medium).** An owner at `aal2` renamed the supplier type a supplier uses and moved it to `lead_source`; the supplier kept a code with no value behind it.
  - **CAT-9 (Medium).** An owner at `aal1` added a tenant value. The table is a named member of STEPUP-1.
- **The repair**, one migration per surface, in the SPEC-300 form (a SECURITY DEFINER guard with an empty `search_path`, executable by no client role, that charges `app.authorize` on every session write and every column; a write with no session, as migrations, seeds, provisioning, `service_role` and fixtures make, is exempt, as in every sibling guard):
  - `20261114120000`: `app.guard_exchange_rate_write`, BEFORE INSERT OR UPDATE, first refuses, for every writer, the platform included, a change of tenant, pair, rate or instant of a rate that a booking item, payment, allocation or adjustment cites (23514), then charges `SET_EXCHANGE_RATE`; `app.emit_exchange_rate_set`, AFTER INSERT OR UPDATE, records every set or change as `exchange_rate_set` at canon 27's `critical`, with the previous and current pair, rate and instant.
  - `20261114130000`: `app.guard_permission_grant_authority`, BEFORE INSERT OR UPDATE, charges `MANAGE_PERMISSIONS`; `app.emit_permission_change` (replaced) records the old row leaving effect and the new row taking effect whenever a live grant's user, permission, effect or tenant changes, through `app.record_permission_change`, with the same event types, entity, payload and severity as before; a reason edit records nothing.
  - `20261114140000`: `app.guard_catalog_value_write`, BEFORE INSERT OR UPDATE, charges `MANAGE_TENANT_SETTINGS`, admits a value only to a `tenant_extendable_system` family and never as a system value, and keeps an updated value's tenant, family and code; label, order and activation stay editable.
  - No grant, policy, RPC, event code or existing trigger changes. Neither table has a DELETE grant.
- **Existing files that move, each for a stated reason.**
  - `10_grant_model_test.sql`: the MEAS-2 inventory of bespoke-guard tables goes from fourteen to seventeen; the assertion exists to force this justification.
  - `92_`, `96_` and `99_`: a fixture grant written after a session claim now clears the leftover claim first, as test 38 has since SPEC-300, so it stays a system-path write; test 92's cross-tenant foreign-key proof is now attempted by the tenant's owner at `aal2`, because an employee is refused before the foreign key is reached.
  - `64_acquisition_lineage_test.sql`: the owner who writes a tenant value is at `aal2`.
  - `101_`: its consumer count of functions that write adjustments leaves out the rate guard, which only reads them.
  - `155_`: assertion 64b now asserts that the rate its payment and allocation cite cannot be rewritten (plan 68 to 69).
  - `scripts/generate-api-contract.ps1`: its two trigger-guard reads take `pg_get_functiondef` only for a plain function (`prokind = 'f'`); under a hash-join plan the old read reached an aggregate and failed. The committed contract is reproduced byte-identically by the old and the repaired generator.
  - `_ORVION_CANONICAL/27_event_catalog.md`: what `exchange_rate_set` and the two permission events record.
  - `MASTER_API_CONTRACT.md`: the generated table-surface rows of the three tables move (insert guard `no` and update guard `no` become `yes` and `conditional`, as for `departments` (SPEC-301) and `document_retention_policies` (SPEC-305)).
- **Swept and found sound, pinned rather than changed:** another tenant reads no rate, grant or value (the scope policies); no DELETE grant on rates or values; an employee is refused at every door by RLS; global catalog values stay read-only to tenants; the platform-permission guard (SUB-3) is unchanged.
- **Recorded positions, not repaired:** a grant's `created_at` is caller-supplied on INSERT and read by nothing that decides (SPEC-216's schema-wide question); a tenant value's label, order or activation change is not recorded (no event type is added); the grant events keep the `warning` severity they have carried since `202607059800`, where canon 27 lists `security` (nothing reads an event's severity).
- **Latent on Primary:** `vrvtsxexkiiiivlkdxzp` holds 0 tenants, 0 exchange rates, 0 permission grants and the 626 global catalog values (read-only, 2026-11-14, ledger 260), so no stored row is affected and no data repair is needed.

## Risks

- **A password-only session can no longer set a rate, grant a permission or write a tenant catalog value** (42501, "multi-factor authentication required for this role"); every role that holds these permissions is MFA-bound, so each must step up first, as for placements (SPEC-300). The tests that wrote at `aal1` or with a leftover claim (10, 64, 92, 96, 99) move as stated; the rest pass unchanged.
- **A cited rate can no longer be corrected in place**, by any writer: the correction is a new rate and an `exchange_rate_adjustments` row, the path canon 27 already registers. A rate nothing cites may still be corrected, and the correction is recorded.
- **Trigger order.** BEFORE triggers fire in name order; each guard refuses before the row is written, and the existing derive and gate triggers are unchanged.
- **Primary deployment is irreversible** and runs only under the exact-SHA Gate-2 record of Step 19. Approval of this contract does not authorize it. Secondary `brplkqmbzffpxqgkkdzo` is never contacted.
- **Gate 1 and Gate 2 of this contract are DELEGATED** under the owner's instructions (class authorization for Batch 6 releases and standing approval of proposals, 2026-11-08 ~10:20 Cairo; publish, promote and hosted deploy ~12:05; slice 9 in run mode 2 with its surfaces in one contract per product, 2026-11-14 ~11:30 Cairo), recorded outside this repository; never a human-typed digest.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-307-rates-grants-and-catalog-values-change-only-with-step-up-and-a-record.md`
- `supabase/migrations/20261114120000_an_exchange_rate_is_set_with_step_up_and_keeps_its_meaning_once_cited.sql`
- `supabase/migrations/20261114130000_a_permission_grant_changes_only_with_step_up_and_every_move_is_recorded.sql`
- `supabase/migrations/20261114140000_a_tenant_catalog_value_extends_only_open_families_and_keeps_its_code.sql`
- `supabase/tests/166_an_exchange_rate_is_set_with_step_up_and_keeps_its_meaning_once_cited_test.sql`
- `supabase/tests/167_a_permission_grant_changes_only_with_step_up_and_every_move_is_recorded_test.sql`
- `supabase/tests/168_a_tenant_catalog_value_extends_only_open_families_and_keeps_its_code_test.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/64_acquisition_lineage_test.sql`
- `supabase/tests/92_capability_grant_model_test.sql`
- `supabase/tests/96_invoice_void_and_eta_boundary_test.sql`
- `supabase/tests/99_role_assignment_temporal_test.sql`
- `supabase/tests/101_marketing_metrics_and_fx_adjustment_surface_test.sql`
- `supabase/tests/155_an_allocation_spends_its_own_payment_on_its_own_invoice_test.sql`
- `scripts/generate-api-contract.ps1`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607041300_create_system_catalog_tables.sql`
- `supabase/migrations/202607041800_create_finance_foundation_tables.sql`
- `supabase/migrations/202607043300_create_rls_policies.sql`
- `supabase/migrations/202607044100_mfa_requirement_enforcement.sql`
- `supabase/migrations/202607051300_complete_catalog_enforcement.sql`
- `supabase/migrations/202607058800_an_exchange_rate_is_a_positive_number_someone_actually_set.sql`
- `supabase/migrations/202607059800_capability_grants_are_per_user_not_only_per_role.sql`
- `supabase/migrations/202607060300_a_customer_ceiling_that_warns_and_converts.sql`
- `supabase/migrations/20261111120000_a_placement_changes_only_with_authority_and_a_record.sql`
- `supabase/migrations/20261112150000_a_document_is_linked_only_by_someone_who_can_read_it.sql`
- `supabase/tests/38_mfa_step_up_test.sql`
- `scripts/verify_database.sql`
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
- `supabase/migrations/202607044100_mfa_requirement_enforcement.sql` (`app.authorize`, `app.requires_mfa`), `202607059800_capability_grants_are_per_user_not_only_per_role.sql` (user grants and their emitter) and `202607051300_complete_catalog_enforcement.sql` (`app.enforce_catalog_codes`)
- `changes/SPEC-300-a-placement-changes-only-with-authority-and-a-record.md` (the guard form, USR-3's first half); `reports/master/MASTER_GAP_REGISTER.md` (FX-1…FX-4, RBAC-5, CAT-1…CAT-6, USR-3, STEPUP-1); `reports/master/MASTER_SURFACE_DISPOSITION.md`; `reports/master/MASTER_EXECUTION_PLAN.md`, Batch 6 method, EC-1…EC-11

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

Pass 1 Design: three surfaces in one contract, each with its own migration, test and disposition row. On `exchange_rates`, one BEFORE INSERT OR UPDATE guard refuses any change to a cited rate for every writer, then charges `app.authorize('SET_EXCHANGE_RATE')` to every session write, and one AFTER INSERT OR UPDATE emitter records `exchange_rate_set`. On `user_permission_grants`, one guard charges `app.authorize('MANAGE_PERMISSIONS')`, and the existing emitter also records moves. On `catalog_values`, one guard charges `app.authorize('MANAGE_TENANT_SETTINGS')`, admits only open families and no system value, and keeps a value's family and code. Tests 166, 167 and 168 pin every refusal beside the writes that must still land, each surface's record and the session-less exemption. The register records six new rows, closes USR-3 and notes STEPUP-1; the disposition records the three surfaces; canon 27 says what the events now record.

Pass 2 Adversarial Review: the design was challenged on the prototype.
- Revoking INSERT and UPDATE from `authenticated` behind new RPCs was rejected. It would add three client surfaces for doors whose only flaw is the missing step-up and the missing record.
- Refusing every rate update was rejected. A rate nothing cites may be corrected, and the correction is now charged and recorded. The citation refusal binds the platform too, because a cited rate's meaning is the money's meaning (mutant M4 exempts the platform and is killed).
- Recording a grant move as a new event code was rejected. `permission_granted` and `permission_revoked` already say who gained and who lost a permission, and RBAC-5's payload is kept.
- Aligning the grant events' severity with canon 27 was rejected as outside the slice's findings; it is recorded as a position.
- Refusing every catalog value update was rejected. Relabel, reorder and deactivation are canon 25's way to retire a value, and `enforce_catalog_codes` already refuses an inactive code on new rows.
- Recording catalog label changes was rejected. They are a tenant setting, and no event type exists for them.
- Refusing session-less writes was rejected. Every sibling guard exempts them, and the seed, provisioning and the fixtures of many tests write rates, grants and values without a session.
- Attacks run on the final bytes. The seven moved tests and every other test that touches the three tables pass. The full suite passes. The generated API contract moves only the three rows. Each held behavior was probed and holds.
- Copying the selector's next target into the manifest was rejected (SPEC-270; SPEC-278's cancellation).

Pass 3 Evidence Refresh: 2026-11-14. Re-measured on byte-identical files in a disposable clone of `b44cad9` with the project-local CLI 3.0.0: the clean reset; tests 166, 167 and 168 and the seven moved tests alone; pgTAP Pass A and B; the three declared HTTP suites; smoke; the probes; all thirteen mutants and the three causal negatives; the structural fingerprints before and after; the API-contract generator (three rows move); the map generator; and repository consistency. Primary and Founder Secondary were read read-only for their ledgers, triggers, tenants, rates, grants and catalog values.

Selected Version: SPEC-307; selected: the smallest repair that closes FX-5, FX-6, USR-3, RBAC-7, CAT-7, CAT-8 and CAT-9 on every session path (three guards in the SPEC-300 form, one per door, the cited-rate refusal binding every writer; the registered exchange_rate_set emitted; the grant emitter records moves; no grant, policy, RPC or event code changed), proven on byte-identical files by the full local protocol, thirteen killed mutants, the probes and the three causal negatives

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A rate is set only with step-up, and a cited rate keeps its meaning for every writer | the table door of every `SET_EXCHANGE_RATE` holder; `app.exchange_rate_as_of`; booking items, payments, allocations and adjustments that cite a rate | WRITE | Migration SHA-256 `f698a40717c89b5c866b74253cb5fff5d3d96fb5d682793b5fdbfb7c3bf14d69`, md5 `7499a1a5ac159a63a9e660d5a600b444`, 3810 bytes, LF, ASCII. Guard `md5(prosrc)` `b32615cfc85296f7784460c5ebf8d430`, SECURITY DEFINER, ACL `{postgres=X/postgres}`; trigger `exchange_rates_guard_write` BEFORE INSERT OR UPDATE. Tests 26, 29, 39, 83, 95, 98, 106, 113 and 126 pass unchanged; 101 and 155 move as stated. |
| Every rate set or change is recorded | readers of `public.events`; canon 27 | WRITE | Emitter `md5(prosrc)` `ae95d491d8c11cf6f3458591283c58f9`, SECURITY DEFINER; trigger `exchange_rates_emit_set` AFTER INSERT OR UPDATE; the registered code `exchange_rate_set` at `critical`; catalog 71/626 unchanged. |
| A permission grant is written only with step-up, and every move is recorded | the table door of every `MANAGE_PERMISSIONS` holder; `app.has_permission`; readers of `public.events` | WRITE | Migration SHA-256 `412e8ccfb185abf6862a2f108b3f8e3300eddad40c4be490bc203a4ec3d74dbe`, md5 `2a2ae979a9b852391e49b68bc903e841`, 3646 bytes, LF, ASCII. Guard `6d25488b68a3eceedfa00d29d29d2f4a`, emitter `4fb7bbe5f7758b88713b292de80eb016` (was `6f1b726353c03e598d19397796f08dce`), helper `d29912102dd7eeca8efd2dcd678a2701`, each SECURITY DEFINER, ACL `{postgres=X/postgres}`; trigger `user_permission_grants_guard_authority` BEFORE INSERT OR UPDATE. Tests 35, 83, 98, 103, 106, 116, 120, 126, 131, 134, 141 and 150 pass unchanged; 10, 92, 96 and 99 move as stated. |
| A tenant catalog value is written only with step-up, only to an open family, never as a system value, and keeps its family and code | the table door of every `MANAGE_TENANT_SETTINGS` holder; `app.enforce_catalog_codes` and every row that carries a tenant code | WRITE | Migration SHA-256 `00f1b6eb9b15115323c08613c7a1da705aeb7a9373b13cbef0ac2cfe5cdf1f1b`, md5 `c7db4d745876f18a8ec9617c2bf65275`, 2374 bytes, LF, ASCII. Guard `2fc6f66be968999abd3152b3b15fbad6`, SECURITY DEFINER, ACL `{postgres=X/postgres}`; trigger `catalog_values_guard_write` BEFORE INSERT OR UPDATE. Tests 07, 08, 11, 12, 15, 22, 25, 35, 42, 47, 93, 100, 104, 106, 114 and 115 pass unchanged; 64 moves as stated. |
| A clean reset holds all three | the local stack; `supabase_migrations.schema_migrations` | WRITE | A clean reset gives 263 migrations, latest `20261114140000`, ledger `5df6fd8c73bbe79255e09e30bdc78378`; the three tables carry 13 triggers (4 on `exchange_rates`, 5 on `user_permission_grants`, 4 on `catalog_values`), of which 4 are new; catalog 71/626. |
| Tests 166, 167 and 168 | `supabase/tests` | WRITE | Test 166 SHA-256 `b0c53221bc95f88caa8a8b255479fb3384674bdb79703eb104533d23926698c7`, md5 `647a4c0bd6f0e703f80884e97ba1efc7`, 8597 bytes, `plan(12)`: 12/12. Test 167 SHA-256 `241e1a745cefb2a3c9d446a58f056e5610eb01719ba88c1f9d646b0b17bf890a`, md5 `56d1aef3559cc4f068ee4d4038916abf`, 6621 bytes, `plan(10)`: 10/10. Test 168 SHA-256 `456abbb4d4f7227265bd54abc92f7cb4ca78f684975d3237388233ef4dab6668`, md5 `89a1a017384e9bc454e2090c40759445`, 6173 bytes, `plan(11)`: 11/11. Each LF, ASCII. |
| The seven moved tests | `supabase/tests` | WRITE | Each moves only as stated in Business Reason; each passes alone on the final bytes (10 9/9, 64 21/21, 92 26/26, 96 32/32, 99 11/11, 101 21/21, 155 69/69). |
| Other tests and the suite | the full pgTAP suite; the HTTP suites; smoke | VERIFY | Pass A `Files=168, Tests=3151`, PASS; HTTP 35/0, 85/0, 122/0; Pass B 168/3151, PASS; smoke `ALL CHECKS PASSED` (78 tables, 71/626 catalog). 168 files whose literal `plan(N)` values sum to 3151. `scripts/verify_database.sql` does not move. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | Before (260): functions `73b0bbffade0a788aff53c10266a97dc`/341, triggers `8f39469bf723f0ea53cccb3c96fb65fd`/328, `_combined` `4a7b00b15007fbdb9072203d1f46ad19`/3160, equal to the recorded Primary evidence. After (263, local): functions `0b3b9c82bb521f6744950201471196a6`/346 (+5), triggers `d241997ceaab37c02327503b4e2587cb`/332 (+4), `_combined` `f87d6fee4ce1857bc3f35672c7ef8a4e`/3169; policies, constraints, grants, columns, views, indexes, status transitions and RLS unchanged. Step 21 writes Primary values only from fresh post-deploy readings. |
| Client API | `MASTER_API_CONTRACT.md` (Check L3); `scripts/generate-api-contract.ps1` | WRITE | No RPC is added, removed or changed; the six functions are trigger functions or a trigger helper, executable by no client role. Measured on the final bytes, the generator's output differs from the committed contract only in the three table-surface rows: `catalog_values`, `exchange_rates` and `user_permission_grants` each move from insert guard `no`, update guard `no` to `yes`, `conditional`; no other line differs. Step 21 regenerates it. The repaired generator reproduces the committed contract byte-identically at `b44cad9`. |
| Measured state that moves | manifest `Live state` and suite figure; `primary-ledger-evidence.json`; `ai-map.json` and `repository-index.md` | WRITE | 260 → 263 migrations, latest `20261114140000`, ledger fingerprint `5df6fd8c73bbe79255e09e30bdc78378`; 165 → 168 files and 3117 → 3151 assertions; coverage 51 → 54 of 78. Tables 78 and client RPCs 80 do not move. `Next capability` and `Current Module` stay unchanged (selector form). |
| The pinned manifest lines `Current Module`, `Next capability` and `Batch 6 surface coverage` | native Boot; `scripts/batch6_select_target.ps1` and `MASTER_SURFACE_DISPOSITION.md`, which own their values (GOVERNANCE.md §6 rule 10) | UNAFFECTED | Step 22 names `Current Module` and `Next capability` only to leave them unchanged; each line keeps its ratified text and pin. |
| FX-5, FX-6, RBAC-7, CAT-7, CAT-8 and CAT-9 fixed; USR-3 closed; STEPUP-1 noted; three surfaces recorded; canon 27 | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; `27_event_catalog.md`; Checks 21, 22, 24, 25, 29 | WRITE | No FX-5, FX-6, RBAC-7, CAT-7, CAT-8 or CAT-9 row exists at `b44cad9`. Each of tests 166-168 declares ten classes on its `-- ATTACK-CLASSES:` line, with its N/A classes reasoned, and carries negative assertions, so Check 24 admits `ADVERSARIAL`. Each new row has Owner `—` and is settled. Coverage 54: 30 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 24 `NOT-RECORDED`; all 54 `ADVERSARIAL`. |
| Repository consistency | `scripts/check_repository_consistency.ps1` | VERIFY | With Steps 1–17 applied and the contract present, consistency reports exactly the six measured-state items (260 vs 263 migrations, latest, ledger fingerprint, 165 vs 168 files, 3117 vs 3151 assertions, the Primary-evidence record) and Checks 21–29 pass. Step 21 makes them true; the one implementation commit is made only after it. |
| The four CI-only guard self-tests | `scripts/test_*_guard.ps1`; `orvion-acceptance` | VERIFY | Unchanged scripts, run by `orvion-acceptance` on the exact candidate SHA before `main` may move to it; their controls require the measured state of Step 21, so they are not run locally (timed once in slice 47: 618 s locally, 84 s in hosted CI). |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 20 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| The applied files equal the verified bytes, and the focused tests, probes, mutants and causal negatives hold | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 18 |
| Primary lacks the three target migrations and its ledger and structure equal the recorded evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 20 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 21 | Step 22 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 4 | Step 21 | Step 22 |
| The map and the API contract match their generators | BEFORE_COMPLETION | Step 1 | Step 21 | Step 22 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: each table's write policy charges a permission through `app.has_permission`, which reads no assurance level; `app.authorize` charges permission and step-up but is called by no trigger on these tables; `app.derive_exchange_rate_setter` fixes who set a rate, not what it says; `exchange_rate_adjustments` records a correction only when someone chooses that path; `app.emit_permission_change` compares liveness only; `app.enforce_catalog_codes` reads a value by tenant or globally and never the family's ownership. Nothing charges step-up at these doors, keeps a cited rate or a used code fixed, or records a rate set or a grant move.

Added Property: For every session, a rate, a user permission grant or a tenant catalog value is written only by a writer who passes `app.authorize` for its permission; a rate that recorded money cites never changes for any writer; a tenant value is added only to a family open to tenants, never as a system value, and keeps its family and code; every rate set and change and every move of a live grant is recorded once with its actor and both values.

Causal Negative: On the `b44cad9` schema (the stack reset to `20261112150000`), and again with each surface's new triggers removed and the grant emitter's pre-repair body restored, test 166 fails assertions 1–5, 7, 8 and 10–12, test 167 fails 1–3, 5, 9 and 10, and test 168 fails 1–7, 9 and 10: the same set both ways. The probes there return: the `aal1` finance manager sets a rate; the cited rate is rewritten, re-dated and turned around unrecorded; the `aal1` ceo grants itself a permission; a live grant moves between users unrecorded; the owner adds values to `payment_direction` and `booking_item_base_status`, claims `is_system`, and renames and moves a value in use.

Positive Test Design: one tenant with an owner, a ceo, a finance manager and employees; a rate cited by a booking item and one cited by nothing; a live grant; a supplier type used by a supplier. Positive controls: a finance manager at `aal2` sets a rate and corrects an uncited one; a ceo at `aal2` grants, moves, denies and annotates a grant; an owner at `aal2` adds a value to an open family and relabels and deactivates one; a session-less write lands at each door.

Negative Test Design:
- **Auth:** each door refuses an `aal1` holder with 42501 and the exact step-up message.
- **Tenant:** another tenant reads and writes nothing (the unchanged scope policies, tests 07, 08, 26 and 83).
- **Door:** INSERT and UPDATE are charged; no table here has a DELETE grant.
- **Input:** a value in a platform-owned family and a value claiming `is_system` are refused with their exact messages.
- **Privilege:** an employee without the permission is refused at each door.
- **Business:** a cited rate is never rewritten, re-dated or turned around, by the platform either, and a value in use keeps its code, so its supplier still finds it.
- **Observability:** a new rate is recorded once with no previous value, and a correction with both; a grant moved between users is recorded as revoked and granted; a grant turned into a deny as leaving and taking effect; a reason edit adds nothing.

Non-Empty Population Obligation: each test's fixture holds its tenant, users, roles and rows before the first assertion (166: two rates, a booking item; 167: a live grant; 168: a tenant value used by a supplier). Each refusal is asserted by its SQLSTATE and exact message; each record by its exact fields.

Mutation Obligation: each mutant is installed inside its test's own rolled-back transaction and proven installed by a diag line (the md5 of the table's slice functions and its trigger count), run, and rolled back. The restored shape is read after the last mutant. A mutant not proven installed is a harness error, never a kill.

| Mutant | Change | Killed on the prototype by |
| --- | --- | --- |
| 166 M1 | the rate guard trigger dropped | 166 assertions 1–5, 7, 8 and 10 |
| 166 M2 | the citation check removed | 166 assertions 4, 5, 8 and 10 |
| 166 M3 | step-up through `app.has_permission` only | 166 assertions 2 and 3 |
| 166 M4 | the session-less writer exempt from the citation check | 166 assertions 8 and 10 |
| 166 M5 | the rate emitter dropped | 166 assertions 1, 11 and 12 |
| 167 M1 | the grant guard trigger dropped | 167 assertions 1–3 and 10 |
| 167 M2 | step-up through `app.has_permission` only | 167 assertions 2 and 3 |
| 167 M3 | the emitter's pre-repair body: a move of a live grant goes unrecorded | 167 assertions 5 and 9 |
| 168 M1 | the catalog guard trigger dropped | 168 assertions 1–7, 9 and 10 |
| 168 M2 | step-up through `app.has_permission` only | 168 assertions 2 and 3 |
| 168 M3 | the `is_system` check removed | 168 assertion 5 |
| 168 M4 | the family check removed | 168 assertion 4 |
| 168 M5 | an update may change the family and code | 168 assertions 6, 7 and 10 |

Post-Implementation Proof Obligation: all of the following on the final bytes, through canonical `-Finish` from the main checkout with the project-local CLI: the clean reset, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke; the generated artifacts, repository consistency and the recorded Primary evidence. Before Step 20: the focused tests, the probes, the mutants, the causal negatives and the fresh Primary baseline of Step 18.

## Implementation Steps

1. Check whether `supabase/migrations/20261114120000_an_exchange_rate_is_set_with_step_up_and_keeps_its_meaning_once_cited.sql` contains `Batch 6 slice 9 (`; if so record Already Applied when its Git blob is 2bd89afb09e54e94b067557baf03bfc62cdc30ee, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the rate migration: the guard and the exchange_rate_set emitter), and change nothing else:

   ```text
   -- Batch 6 slice 9 (`exchange_rates`). Measured on the local stack before this file (probes ER1-ER3):
   --   * a finance_manager, ceo or owner set a rate from a password-only (aal1) session: the table door charged
   --     SET_EXCHANGE_RATE through RLS but never the step-up `app.authorize` charges every MFA-bound role;
   --   * a rate that a booking item already cited was rewritten (48.5 -> 99), re-dated a year back and had its currency
   --     pair flipped in place; `app.exchange_rate_as_of` answered the new value, `set_by` still named the first setter,
   --     and nothing was recorded. `exchange_rate_adjustments` (append-only) is the designed correction path.
   -- Repair: every session write charges `app.authorize('SET_EXCHANGE_RATE')`; a rate cited by a booking item, a payment,
   -- an allocation or an adjustment keeps its rate, pair, instant and tenant for every writer; every set or change of a
   -- rate is recorded as the registered `exchange_rate_set` event, at canon 27's severity (critical).

   create or replace function app.guard_exchange_rate_write()
   returns trigger
   language plpgsql
   security definer
   set search_path = ''
   as $fn$
   begin
       if tg_op = 'UPDATE'
          and (new.tenant_id, new.from_currency_code, new.to_currency_code, new.rate, new.effective_at)
              is distinct from (old.tenant_id, old.from_currency_code, old.to_currency_code, old.rate, old.effective_at)
          and (exists (select 1 from public.booking_items b
                        where b.tenant_id = old.tenant_id and b.exchange_rate_id = old.id)
               or exists (select 1 from public.payments p
                           where p.tenant_id = old.tenant_id and p.exchange_rate_id = old.id)
               or exists (select 1 from public.payment_allocations a
                           where a.tenant_id = old.tenant_id and a.exchange_rate_id = old.id)
               or exists (select 1 from public.exchange_rate_adjustments x
                           where x.tenant_id = old.tenant_id
                             and (x.original_exchange_rate_id = old.id or x.new_exchange_rate_id = old.id))) then
           raise exception 'exchange rate % is cited by recorded money: set a new rate and record an adjustment', old.id
               using errcode = 'check_violation';
       end if;
       if (select auth.uid()) is null then
           return new;
       end if;
       perform app.authorize('SET_EXCHANGE_RATE');
       return new;
   end;
   $fn$;

   revoke execute on function app.guard_exchange_rate_write() from public;

   create trigger exchange_rates_guard_write
       before insert or update on public.exchange_rates
       for each row execute function app.guard_exchange_rate_write();

   create or replace function app.emit_exchange_rate_set()
   returns trigger
   language plpgsql
   security definer
   set search_path = ''
   as $fn$
   declare
       v_prev jsonb;
       v_next jsonb;
   begin
       v_next := jsonb_build_object('from_currency_code', new.from_currency_code, 'to_currency_code', new.to_currency_code,
           'rate', new.rate, 'effective_at', new.effective_at);
       if tg_op = 'UPDATE' then
           v_prev := jsonb_build_object('from_currency_code', old.from_currency_code, 'to_currency_code', old.to_currency_code,
               'rate', old.rate, 'effective_at', old.effective_at);
           if v_prev = v_next then
               return null;
           end if;
       end if;
       perform app.record_event(
           new.tenant_id, 'exchange_rate_set', 'exchange_rate', new.id,
           null, null, null, null,
           jsonb_build_object('exchange_rate_id', new.id, 'previous', v_prev, 'current', v_next),
           'critical');
       return null;
   end;
   $fn$;

   revoke execute on function app.emit_exchange_rate_set() from public;

   create trigger exchange_rates_emit_set
       after insert or update on public.exchange_rates
       for each row execute function app.emit_exchange_rate_set();
   ```

   The resulting file's Git blob is 2bd89afb09e54e94b067557baf03bfc62cdc30ee.

2. Check whether `supabase/migrations/20261114130000_a_permission_grant_changes_only_with_step_up_and_every_move_is_recorded.sql` contains `Batch 6 slice 9 (`; if so record Already Applied when its Git blob is fe62f40f4df3636db6693837564e84fc7a246a23, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the grant migration: the guard and the emitter that records moves), and change nothing else:

   ```text
   -- Batch 6 slice 9 (`user_permission_grants`). Measured on the local stack before this file (probes UPG1-UPG4):
   --   * USR-3: a ceo at aal1 granted itself a permission at the table door; MANAGE_PERMISSIONS was charged through RLS,
   --     never the step-up `app.authorize` charges every MFA-bound role (the user_branch_assignments half closed in SPEC-300);
   --   * a live grant was re-pointed to another user, to another permission (MANAGE_PERMISSIONS) and turned from grant to
   --     deny by UPDATE, and `app.emit_permission_change` recorded none of it: it compared only liveness, which stayed true.
   -- Repair: every session write charges `app.authorize('MANAGE_PERMISSIONS')`; the emitter records the old row leaving
   -- effect and the new row taking effect whenever the user, permission, effect or tenant of a live row changes, with the
   -- same event types, entity and payload as before.

   create or replace function app.guard_permission_grant_authority()
   returns trigger
   language plpgsql
   security definer
   set search_path = ''
   as $fn$
   begin
       if (select auth.uid()) is null then
           return new;
       end if;
       perform app.authorize('MANAGE_PERMISSIONS');
       return new;
   end;
   $fn$;

   revoke execute on function app.guard_permission_grant_authority() from public;

   create trigger user_permission_grants_guard_authority
       before insert or update on public.user_permission_grants
       for each row execute function app.guard_permission_grant_authority();

   create or replace function app.record_permission_change(
       p_tenant uuid, p_user uuid, p_permission uuid, p_effect text, p_now_live boolean)
   returns void
   language plpgsql
   security definer
   set search_path = ''
   as $fn$
   declare
       v_key text;
   begin
       select p.key into v_key from public.permissions p where p.id = p_permission;
       perform app.record_event(
           p_tenant,
           case when (p_effect = 'grant') = p_now_live then 'permission_granted' else 'permission_revoked' end,
           'user', p_user,
           (select id from public.users where auth_user_id = (select auth.uid()) and tenant_id = p_tenant),
           null, null, null,
           jsonb_build_object('permission_key', v_key, 'effect', p_effect, 'now_live', p_now_live),
           'warning');
   end;
   $fn$;

   revoke execute on function app.record_permission_change(uuid, uuid, uuid, text, boolean) from public;

   create or replace function app.emit_permission_change()
   returns trigger
   language plpgsql
   security definer
   set search_path = ''
   as $fn$
   declare
       -- OLD is read only on the branches where it is assigned (UPDATE, DELETE), NEW only where it is (INSERT, UPDATE).
       v_was_live boolean := false;
       v_now_live boolean := false;
       v_moved boolean := false;
   begin
       if tg_op <> 'INSERT' then
           v_was_live := old.is_active and (old.ends_at is null or old.ends_at > now());
       end if;
       if tg_op <> 'DELETE' then
           v_now_live := new.is_active and (new.ends_at is null or new.ends_at > now());
       end if;
       if tg_op = 'UPDATE' then
           v_moved := (old.tenant_id, old.user_id, old.permission_id, old.effect)
                      is distinct from (new.tenant_id, new.user_id, new.permission_id, new.effect);
       end if;

       -- Only a change in EFFECTIVE privilege is an event: an edit to `reason` stays silent.
       if v_was_live and (v_moved or not v_now_live) then
           perform app.record_permission_change(old.tenant_id, old.user_id, old.permission_id, old.effect, false);
       end if;
       if v_now_live and (v_moved or not v_was_live) then
           perform app.record_permission_change(new.tenant_id, new.user_id, new.permission_id, new.effect, true);
       end if;
       return null;
   end;
   $fn$;
   ```

   The resulting file's Git blob is fe62f40f4df3636db6693837564e84fc7a246a23.

3. Check whether `supabase/migrations/20261114140000_a_tenant_catalog_value_extends_only_open_families_and_keeps_its_code.sql` contains `Batch 6 slice 9 (`; if so record Already Applied when its Git blob is e0678f33c8e458b74af66f8e93ae1b7fc3300504, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the catalog value migration: the guard), and change nothing else:

   ```text
   -- Batch 6 slice 9 (`catalog_values`). Measured on the local stack before this file (probes CV1-CV5):
   --   * an owner wrote tenant values from a password-only (aal1) session: MANAGE_TENANT_SETTINGS was charged through RLS,
   --     never the step-up `app.authorize` charges every MFA-bound role;
   --   * a tenant added its own values to platform-owned families (`payment_direction`, `booking_item_base_status`): the
   --     policy reads only the tenant, never `catalog_types.ownership_type`, and `app.enforce_catalog_codes` then accepts
   --     that value on the tenant's rows;
   --   * a tenant value in use was renamed and moved to another family, leaving the supplier that used it holding a code
   --     with no value behind it; and a tenant value claimed `is_system`.
   -- Repair: every session write charges `app.authorize('MANAGE_TENANT_SETTINGS')`, adds only to a
   -- `tenant_extendable_system` family, never as a system value, and an UPDATE keeps the value's family, code and
   -- tenant (a replaced value is added anew and the old one deactivated, which `enforce_catalog_codes` already allows).

   create or replace function app.guard_catalog_value_write()
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
       if new.is_system then
           raise exception 'a tenant catalog value cannot be a system value' using errcode = '42501';
       end if;
       if not exists (select 1 from public.catalog_types t
                       where t.code = new.catalog_type_code and t.ownership_type = 'tenant_extendable_system') then
           raise exception 'catalog family % does not take tenant values', new.catalog_type_code using errcode = '42501';
       end if;
       if tg_op = 'UPDATE'
          and (new.tenant_id, new.catalog_type_code, new.code) is distinct from (old.tenant_id, old.catalog_type_code, old.code) then
           raise exception 'a catalog value keeps its family and code: add a new value and deactivate this one'
               using errcode = '42501';
       end if;
       return new;
   end;
   $fn$;

   revoke execute on function app.guard_catalog_value_write() from public;

   create trigger catalog_values_guard_write
       before insert or update on public.catalog_values
       for each row execute function app.guard_catalog_value_write();
   ```

   The resulting file's Git blob is e0678f33c8e458b74af66f8e93ae1b7fc3300504.

4. Check whether `supabase/tests/166_an_exchange_rate_is_set_with_step_up_and_keeps_its_meaning_once_cited_test.sql` contains `plan(12)`; if so record Already Applied when its Git blob is ea86cc11ed685a1306cd6ad19eef21d6961a5f00, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (test 166, 12 assertions), and change nothing else:

   ```text
   -- pgTAP: Batch 6 slice 51 (exchange_rates) --
   -- an exchange rate is set only with step-up, a rate that money cites keeps its meaning, and every set is recorded
   -- (`20261114120000`).
   -- ATTACK-CLASSES: AUTH TENANT=N/A DOOR STATE=N/A INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS OBSERVABILITY
   --   TENANT=N/A -- tenant isolation is the unchanged scope_read and scope_insert policies (tests 26, 101).
   --   STATE=N/A -- a rate has no lifecycle; its only change is a rewrite, which is checked and recorded here.
   --   CONCURRENCY=N/A -- the citation check reads committed rows; a rate is cited only after it exists.
   --   REPLAY=N/A -- no token, nonce or idempotency key on this surface.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(12);

   insert into auth.users (id, email) values
     ('16600000-0000-0000-0000-0000000000a1','finance@c166.test'),
     ('16600000-0000-0000-0000-0000000000a2','employee@c166.test');
   insert into public.tenants (id, name, slug, status) values
     ('16600000-0000-0000-0000-000000000001','Rate Travel','rate-travel-166','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select '16600000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug) values
     ('16600000-0000-0000-0000-00000000000a','16600000-0000-0000-0000-000000000001','Giza','giza-166');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
     ('16600000-0000-0000-0000-0000000000c1','16600000-0000-0000-0000-000000000001','16600000-0000-0000-0000-00000000000a','sales','Giza Sales');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('16600000-0000-0000-0000-000000000011','16600000-0000-0000-0000-000000000001','Finance','finance@c166.test',true,'16600000-0000-0000-0000-0000000000a1'),
     ('16600000-0000-0000-0000-000000000012','16600000-0000-0000-0000-000000000001','Employee','employee@c166.test',true,'16600000-0000-0000-0000-0000000000a2');
   insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
     ('16600000-0000-0000-0000-000000000001','16600000-0000-0000-0000-000000000011','16600000-0000-0000-0000-00000000000a','16600000-0000-0000-0000-0000000000c1',true),
     ('16600000-0000-0000-0000-000000000001','16600000-0000-0000-0000-000000000012','16600000-0000-0000-0000-00000000000a','16600000-0000-0000-0000-0000000000c1',true);
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select '16600000-0000-0000-0000-000000000001', v.uid, r.id, 'tenant'
   from (values ('16600000-0000-0000-0000-000000000011'::uuid,'finance_manager'),
                ('16600000-0000-0000-0000-000000000012','employee')) v(uid, role_code)
   join public.roles r on r.code = v.role_code;
   -- R1 is cited by a booking item; R2 is cited by nothing.
   insert into public.exchange_rates (id, tenant_id, from_currency_code, to_currency_code, rate, effective_at) values
     ('16600000-0000-0000-0000-0000000000e1','16600000-0000-0000-0000-000000000001','USD','EGP',48.5,now() - interval '1 day'),
     ('16600000-0000-0000-0000-0000000000e2','16600000-0000-0000-0000-000000000001','EUR','EGP',52,now() - interval '1 day');
   insert into public.customers (id, tenant_id, customer_type_code, full_name) values
     ('16600000-0000-0000-0000-0000000000d1','16600000-0000-0000-0000-000000000001','person','Rate Customer');
   insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                                owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
     ('16600000-0000-0000-0000-0000000000f1','16600000-0000-0000-0000-000000000001','16600000-0000-0000-0000-00000000000a','16600000-0000-0000-0000-0000000000c1','16600000-0000-0000-0000-0000000000d1','16600000-0000-0000-0000-000000000012','16600000-0000-0000-0000-00000000000a','16600000-0000-0000-0000-0000000000c1','draft','Rate booking','BK-166-1');
   insert into public.booking_items (tenant_id, booking_id, service_type_code, base_status_code, currency_code,
                                     cost_amount, selling_amount, exchange_rate_id) values
     ('16600000-0000-0000-0000-000000000001','16600000-0000-0000-0000-0000000000f1','flight_ticket','draft','USD',100,120,'16600000-0000-0000-0000-0000000000e1');

   select is(
     (select count(*)::int from pg_trigger
      where tgrelid = 'public.exchange_rates'::regclass and not tgisinternal
        and tgname in ('exchange_rates_guard_write', 'exchange_rates_emit_set')),
     2, 'both triggers are installed on exchange_rates');

   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"16600000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);

   select throws_ok(
     $$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at)
       values ('16600000-0000-0000-0000-000000000001','GBP','EGP',61,now())$$,
     '42501', 'multi-factor authentication required for this role',
     'a finance manager cannot set a rate from a password-only session');

   select set_config('request.jwt.claims', '{"sub":"16600000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);

   select lives_ok(
     $$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at)
       values ('16600000-0000-0000-0000-000000000001','GBP','EGP',61,now())$$,
     'a finance manager at aal2 sets a rate');

   select throws_ok(
     $$update public.exchange_rates set rate = 99 where id = '16600000-0000-0000-0000-0000000000e1'$$,
     '23514', 'exchange rate 16600000-0000-0000-0000-0000000000e1 is cited by recorded money: set a new rate and record an adjustment',
     'a rate a booking item cites cannot be rewritten');

   select throws_ok(
     $$update public.exchange_rates set effective_at = now() - interval '1 year', from_currency_code = 'EGP', to_currency_code = 'USD'
       where id = '16600000-0000-0000-0000-0000000000e1'$$,
     '23514', 'exchange rate 16600000-0000-0000-0000-0000000000e1 is cited by recorded money: set a new rate and record an adjustment',
     '...nor re-dated or turned around');

   select lives_ok(
     $$update public.exchange_rates set rate = 53 where id = '16600000-0000-0000-0000-0000000000e2'$$,
     'a rate nothing cites may still be corrected');

   select set_config('request.jwt.claims', '{"sub":"16600000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);

   select throws_ok(
     $$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at)
       values ('16600000-0000-0000-0000-000000000001','GBP','EGP',62,now())$$,
     '42501', 'permission denied: SET_EXCHANGE_RATE',
     'an employee without SET_EXCHANGE_RATE cannot set a rate');

   reset role;
   select set_config('request.jwt.claims', null, true);

   select throws_ok(
     $$update public.exchange_rates set rate = 99 where id = '16600000-0000-0000-0000-0000000000e1'$$,
     '23514', 'exchange rate 16600000-0000-0000-0000-0000000000e1 is cited by recorded money: set a new rate and record an adjustment',
     'a cited rate keeps its meaning for every writer, a system writer too');

   select lives_ok(
     $$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at)
       values ('16600000-0000-0000-0000-000000000001','SAR','EGP',13,now())$$,
     'the guard''s one exemption: a session-less platform write sets a rate');

   select is((select rate from public.exchange_rates where id = '16600000-0000-0000-0000-0000000000e1'), 48.5::numeric,
     'the cited rate is still 48.5');

   select is(
     (select count(*)::int from public.events e join public.users u on u.id = e.actor_user_id
      where e.tenant_id = '16600000-0000-0000-0000-000000000001' and e.event_type_code = 'exchange_rate_set'
        and u.full_name = 'Finance' and e.payload -> 'current' ->> 'from_currency_code' = 'GBP'
        and e.payload ->> 'previous' is null and e.severity_code = 'critical'),
     1, 'the new rate is recorded once, as exchange_rate_set by its setter, at canon 27''s severity');

   select is(
     (select count(*)::int from public.events e
      where e.tenant_id = '16600000-0000-0000-0000-000000000001' and e.event_type_code = 'exchange_rate_set'
        and e.entity_id = '16600000-0000-0000-0000-0000000000e2'
        and (e.payload -> 'previous' ->> 'rate')::numeric = 52 and (e.payload -> 'current' ->> 'rate')::numeric = 53),
     1, 'the correction is recorded with the previous and the current rate');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is ea86cc11ed685a1306cd6ad19eef21d6961a5f00.

5. Check whether `supabase/tests/167_a_permission_grant_changes_only_with_step_up_and_every_move_is_recorded_test.sql` contains `plan(10)`; if so record Already Applied when its Git blob is 286d02370f03aa8f9dc63df55ab60e626d1cf15c, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (test 167, 10 assertions), and change nothing else:

   ```text
   -- pgTAP: Batch 6 slice 51 (user_permission_grants, USR-3) --
   -- a permission grant is written only with step-up, and every change of who holds what is recorded
   -- (`20261114130000`).
   -- ATTACK-CLASSES: AUTH TENANT=N/A DOOR STATE=N/A INPUT=N/A CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS=N/A OBSERVABILITY
   --   TENANT=N/A -- tenant isolation is the unchanged scope policies (tests 10, 83).
   --   STATE=N/A -- liveness is the only state; its changes are checked here.
   --   INPUT=N/A -- effect and period are the unchanged checks of the table.
   --   CONCURRENCY=N/A -- one row per change; no counter or claim.
   --   REPLAY=N/A -- no token, nonce or idempotency key on this surface.
   --   BUSINESS=N/A -- which permissions a tenant may grant is SUB-3's guard (test 120), unchanged.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(10);

   insert into auth.users (id, email) values
     ('16700000-0000-0000-0000-0000000000a1','ceo@c167.test'),
     ('16700000-0000-0000-0000-0000000000a2','first@c167.test'),
     ('16700000-0000-0000-0000-0000000000a3','second@c167.test');
   insert into public.tenants (id, name, slug, status) values
     ('16700000-0000-0000-0000-000000000001','Grant Travel','grant-travel-167','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select '16700000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('16700000-0000-0000-0000-000000000011','16700000-0000-0000-0000-000000000001','Ceo','ceo@c167.test',true,'16700000-0000-0000-0000-0000000000a1'),
     ('16700000-0000-0000-0000-000000000012','16700000-0000-0000-0000-000000000001','First','first@c167.test',true,'16700000-0000-0000-0000-0000000000a2'),
     ('16700000-0000-0000-0000-000000000013','16700000-0000-0000-0000-000000000001','Second','second@c167.test',true,'16700000-0000-0000-0000-0000000000a3');
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select '16700000-0000-0000-0000-000000000001', v.uid, r.id, 'tenant'
   from (values ('16700000-0000-0000-0000-000000000011'::uuid,'ceo'),
                ('16700000-0000-0000-0000-000000000012','employee'),
                ('16700000-0000-0000-0000-000000000013','employee')) v(uid, role_code)
   join public.roles r on r.code = v.role_code;
   insert into public.user_permission_grants (id, tenant_id, user_id, permission_id, effect)
   select '16700000-0000-0000-0000-0000000000e1', '16700000-0000-0000-0000-000000000001',
          '16700000-0000-0000-0000-000000000012', p.id, 'grant'
   from public.permissions p where p.key = 'VIEW_DEPARTMENT_RECORDS';

   select is(
     (select count(*)::int from pg_trigger
      where tgrelid = 'public.user_permission_grants'::regclass and not tgisinternal
        and tgname = 'user_permission_grants_guard_authority'),
     1, 'the authority guard is installed on user_permission_grants');

   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"16700000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);

   select throws_ok(
     $$insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect)
       select '16700000-0000-0000-0000-000000000001', '16700000-0000-0000-0000-000000000011', p.id, 'grant'
       from public.permissions p where p.key = 'VIEW_ADVANCED_DASHBOARDS'$$,
     '42501', 'multi-factor authentication required for this role',
     'USR-3: a ceo cannot grant itself a permission from a password-only session');

   select set_config('request.jwt.claims', '{"sub":"16700000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);

   select lives_ok(
     $$insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect)
       select '16700000-0000-0000-0000-000000000001', '16700000-0000-0000-0000-000000000011', p.id, 'grant'
       from public.permissions p where p.key = 'VIEW_ADVANCED_DASHBOARDS'$$,
     'a ceo at aal2 grants a permission');

   select lives_ok(
     $$update public.user_permission_grants set user_id = '16700000-0000-0000-0000-000000000013'
       where id = '16700000-0000-0000-0000-0000000000e1'$$,
     'a ceo at aal2 moves a live grant from one user to another');

   reset role;

   select is(
     (select string_agg(u.full_name || ':' || e.event_type_code, ',' order by u.full_name)
      from public.events e join public.users u on u.id = e.entity_id
      where e.tenant_id = '16700000-0000-0000-0000-000000000001' and e.entity_type = 'user'
        and e.actor_user_id = '16700000-0000-0000-0000-000000000011'
        and e.payload ->> 'permission_key' = 'VIEW_DEPARTMENT_RECORDS'),
     'First:permission_revoked,Second:permission_granted',
     'the move is recorded twice: revoked from the first user, granted to the second');

   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"16700000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);

   select lives_ok(
     $$update public.user_permission_grants set effect = 'deny' where id = '16700000-0000-0000-0000-0000000000e1'$$,
     'a ceo at aal2 turns the live grant into a deny');

   select lives_ok(
     $$update public.user_permission_grants set reason = 'reviewed' where id = '16700000-0000-0000-0000-0000000000e1'$$,
     'a reason edit is allowed');

   reset role;
   select set_config('request.jwt.claims', null, true);

   select lives_ok(
     $$insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect)
       select '16700000-0000-0000-0000-000000000001', '16700000-0000-0000-0000-000000000012', p.id, 'grant'
       from public.permissions p where p.key = 'VIEW_ADVANCED_DASHBOARDS'$$,
     'the guard''s one exemption: a session-less platform write grants a permission');

   select is(
     (select count(*)::int from public.events e
      where e.tenant_id = '16700000-0000-0000-0000-000000000001' and e.entity_id = '16700000-0000-0000-0000-000000000013'
        and e.event_type_code = 'permission_revoked'),
     2, 'grant to deny is recorded as the grant leaving and the deny taking effect; the reason edit adds nothing');

   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"16700000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);

   select throws_ok(
     $$insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect)
       select '16700000-0000-0000-0000-000000000001', '16700000-0000-0000-0000-000000000012', p.id, 'grant'
       from public.permissions p where p.key = 'MANAGE_PERMISSIONS'$$,
     '42501', 'permission denied: MANAGE_PERMISSIONS',
     'an employee cannot grant itself MANAGE_PERMISSIONS');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 286d02370f03aa8f9dc63df55ab60e626d1cf15c.

6. Check whether `supabase/tests/168_a_tenant_catalog_value_extends_only_open_families_and_keeps_its_code_test.sql` contains `plan(11)`; if so record Already Applied when its Git blob is 2fd246de59157743388bc55f7e94172e17899a7a, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (test 168, 11 assertions), and change nothing else:

   ```text
   -- pgTAP: Batch 6 slice 51 (catalog_values) --
   -- a tenant catalog value is written only with step-up, only in a family open to tenants, never as a system value, and
   -- keeps its family and code (`20261114140000`).
   -- ATTACK-CLASSES: AUTH TENANT=N/A DOOR STATE=N/A INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS OBSERVABILITY=N/A
   --   TENANT=N/A -- global values stay read-only to tenants through the unchanged policies (tests 07, 08).
   --   STATE=N/A -- activation is the only state; deactivation stays allowed and is what enforce_catalog_codes reads.
   --   CONCURRENCY=N/A -- one row per write; uniqueness is the unchanged partial indexes.
   --   REPLAY=N/A -- no token, nonce or idempotency key on this surface.
   --   OBSERVABILITY=N/A -- a tenant setting's label, order or activation is not recorded (slice 51 position).
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(11);

   insert into auth.users (id, email) values
     ('16800000-0000-0000-0000-0000000000a1','owner@c168.test'),
     ('16800000-0000-0000-0000-0000000000a2','employee@c168.test');
   insert into public.tenants (id, name, slug, status) values
     ('16800000-0000-0000-0000-000000000001','Catalog Travel','catalog-travel-168','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select '16800000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('16800000-0000-0000-0000-000000000011','16800000-0000-0000-0000-000000000001','Owner','owner@c168.test',true,'16800000-0000-0000-0000-0000000000a1'),
     ('16800000-0000-0000-0000-000000000012','16800000-0000-0000-0000-000000000001','Employee','employee@c168.test',true,'16800000-0000-0000-0000-0000000000a2');
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select '16800000-0000-0000-0000-000000000001', v.uid, r.id, 'tenant'
   from (values ('16800000-0000-0000-0000-000000000011'::uuid,'owner'),
                ('16800000-0000-0000-0000-000000000012','employee')) v(uid, role_code)
   join public.roles r on r.code = v.role_code;
   insert into public.catalog_values (id, tenant_id, catalog_type_code, code, label) values
     ('16800000-0000-0000-0000-0000000000e1','16800000-0000-0000-0000-000000000001','supplier_type','charter168','Charter');
   insert into public.suppliers (id, tenant_id, supplier_type_code, name) values
     ('16800000-0000-0000-0000-0000000000f1','16800000-0000-0000-0000-000000000001','charter168','Charter Supplier');

   select is(
     (select count(*)::int from pg_trigger
      where tgrelid = 'public.catalog_values'::regclass and not tgisinternal and tgname = 'catalog_values_guard_write'),
     1, 'the guard is installed on catalog_values');

   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"16800000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);

   select throws_ok(
     $$insert into public.catalog_values (tenant_id, catalog_type_code, code, label)
       values ('16800000-0000-0000-0000-000000000001','supplier_type','barge168','Barge')$$,
     '42501', 'multi-factor authentication required for this role',
     'an owner cannot add a tenant value from a password-only session');

   select set_config('request.jwt.claims', '{"sub":"16800000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);

   select lives_ok(
     $$insert into public.catalog_values (tenant_id, catalog_type_code, code, label)
       values ('16800000-0000-0000-0000-000000000001','supplier_type','barge168','Barge')$$,
     'an owner at aal2 adds a value to a family open to tenants');

   select throws_ok(
     $$insert into public.catalog_values (tenant_id, catalog_type_code, code, label)
       values ('16800000-0000-0000-0000-000000000001','payment_direction','sideways','Sideways')$$,
     '42501', 'catalog family payment_direction does not take tenant values',
     'a tenant cannot add a value to a platform-owned family');

   select throws_ok(
     $$insert into public.catalog_values (tenant_id, catalog_type_code, code, label, is_system)
       values ('16800000-0000-0000-0000-000000000001','supplier_type','sys168','Sys',true)$$,
     '42501', 'a tenant catalog value cannot be a system value',
     'a tenant value cannot claim to be a system value');

   select throws_ok(
     $$update public.catalog_values set code = 'renamed168' where id = '16800000-0000-0000-0000-0000000000e1'$$,
     '42501', 'a catalog value keeps its family and code: add a new value and deactivate this one',
     'a value in use cannot be renamed under the rows that use it');

   select throws_ok(
     $$update public.catalog_values set catalog_type_code = 'lead_source' where id = '16800000-0000-0000-0000-0000000000e1'$$,
     '42501', 'a catalog value keeps its family and code: add a new value and deactivate this one',
     '...nor moved to another family');

   select lives_ok(
     $$update public.catalog_values set label = 'Charter (old)', is_active = false where id = '16800000-0000-0000-0000-0000000000e1'$$,
     'a value may be relabelled and deactivated');

   select set_config('request.jwt.claims', '{"sub":"16800000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);

   select throws_ok(
     $$insert into public.catalog_values (tenant_id, catalog_type_code, code, label)
       values ('16800000-0000-0000-0000-000000000001','supplier_type','emp168','E')$$,
     '42501', 'permission denied: MANAGE_TENANT_SETTINGS',
     'an employee cannot add a tenant value');

   reset role;

   select is(
     (select count(*)::int from public.suppliers s join public.catalog_values cv
        on cv.tenant_id = s.tenant_id and cv.catalog_type_code = 'supplier_type' and cv.code = s.supplier_type_code
      where s.id = '16800000-0000-0000-0000-0000000000f1'),
     1, 'the supplier still finds the value it uses');

   select set_config('request.jwt.claims', null, true);

   select lives_ok(
     $$insert into public.catalog_values (tenant_id, catalog_type_code, code, label)
       values ('16800000-0000-0000-0000-000000000001','supplier_type','plat168','Platform')$$,
     'the guard''s one exemption: a session-less platform write adds a tenant value');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 2fd246de59157743388bc55f7e94172e17899a7a.

7. Check whether `supabase/tests/10_grant_model_test.sql` contains `exactly these SEVENTEEN tables`; if so record Already Applied when its Git blob is 942107d11b89dfa2a6c515f39995f26219e9f624, and otherwise stop and report. Otherwise make exactly these 2 edits (MEAS-2 counts seventeen bespoke-guard tables), each matched once, and change nothing else:

   a) immediately after the line
   ```text
   -- remove the guard.
   ```
   insert
   ```text
   --
   -- IT WENT FROM FOURTEEN TO SEVENTEEN ON 2026-11-14 (Batch 6 slice 51, `20261114120000`, `20261114130000`,
   -- `20261114140000`). `exchange_rates` joined through `app.guard_exchange_rate_write` (SET_EXCHANGE_RATE),
   -- `user_permission_grants` through `app.guard_permission_grant_authority` (MANAGE_PERMISSIONS, USR-3) and
   -- `catalog_values` through `app.guard_catalog_value_write` (MANAGE_TENANT_SETTINGS): each door now asks for the
   -- step-up its MFA-bound holders owe. `guard_write_capability` has no mapping for these tables. Each charge is
   -- UNCONDITIONAL for every signed-in caller, on INSERT and UPDATE and every column; the one exemption, the
   -- SESSION-LESS platform write, is pinned by `166_...`, `167_...` and `168_...`, and the slice's mutants remove
   -- each guard. The exchange-rate guard's citation refusal comes before the exemption and binds every writer.
   ```

   b) replace the lines
   ```text
     array['chart_of_accounts','departments','document_retention_policies','document_versions','invoices','lead_interactions','payment_allocations',
           'payments','quotation_items','receipts','refunds','user_branch_assignments','user_role_assignments','users'],
     'MEAS-2: exactly these FOURTEEN tables are credited by a BESPOKE capability trigger rather than by guard_write_capability, so for each of them "credited" means "a human read its short-circuits". Nine until 2026-09-20, when SPEC-203 gave users app.guard_membership_authority -- admissible only because that guard charges app.authorize unconditionally on every path and every column, and its only two exemptions, the session-less platform write and the activate_membership self-claim, are each pinned by a named assertion in 118_membership_authority_and_audit_test.sql. Eleven since 2026-10-13, when SPEC-278 gave chart_of_accounts app.guard_chart_account -- the same unconditional charge, its one session-less exemption pinned by 157_a_used_ledger_account_keeps_its_meaning_test.sql. Twelve since 2026-11-11, when SPEC-300 gave user_branch_assignments app.guard_placement_authority -- the same unconditional charge, its one session-less exemption pinned by 160_a_placement_changes_only_with_authority_and_a_record_test.sql. Thirteen since 2026-11-11, when Batch 6 slice 4 gave departments app.guard_department_write -- the same unconditional charge, its one session-less exemption pinned by 161_a_department_stays_in_its_branch_and_changes_only_with_authority_and_a_record_test.sql. Fourteen since 2026-11-11, when Batch 6 slice 7 gave document_retention_policies app.guard_document_retention_policy_write -- the same unconditional charge, its one session-less exemption pinned by 164_a_retention_period_changes_only_with_step_up_and_a_record_test.sql');
   ```
   with
   ```text
     array['catalog_values','chart_of_accounts','departments','document_retention_policies','document_versions','exchange_rates','invoices','lead_interactions','payment_allocations',
           'payments','quotation_items','receipts','refunds','user_branch_assignments','user_permission_grants','user_role_assignments','users'],
     'MEAS-2: exactly these SEVENTEEN tables are credited by a BESPOKE capability trigger rather than by guard_write_capability, so for each of them "credited" means "a human read its short-circuits". Nine until 2026-09-20, when SPEC-203 gave users app.guard_membership_authority -- admissible only because that guard charges app.authorize unconditionally on every path and every column, and its only two exemptions, the session-less platform write and the activate_membership self-claim, are each pinned by a named assertion in 118_membership_authority_and_audit_test.sql. Eleven since 2026-10-13, when SPEC-278 gave chart_of_accounts app.guard_chart_account -- the same unconditional charge, its one session-less exemption pinned by 157_a_used_ledger_account_keeps_its_meaning_test.sql. Twelve since 2026-11-11, when SPEC-300 gave user_branch_assignments app.guard_placement_authority -- the same unconditional charge, its one session-less exemption pinned by 160_a_placement_changes_only_with_authority_and_a_record_test.sql. Thirteen since 2026-11-11, when Batch 6 slice 4 gave departments app.guard_department_write -- the same unconditional charge, its one session-less exemption pinned by 161_a_department_stays_in_its_branch_and_changes_only_with_authority_and_a_record_test.sql. Fourteen since 2026-11-11, when Batch 6 slice 7 gave document_retention_policies app.guard_document_retention_policy_write -- the same unconditional charge, its one session-less exemption pinned by 164_a_retention_period_changes_only_with_step_up_and_a_record_test.sql. Seventeen since 2026-11-14, when Batch 6 slice 51 gave exchange_rates, user_permission_grants and catalog_values their own step-up guards -- the same unconditional charge, each session-less exemption pinned by tests 166, 167 and 168.');
   ```

   The resulting file's Git blob is 942107d11b89dfa2a6c515f39995f26219e9f624.

8. Check whether `supabase/tests/64_acquisition_lineage_test.sql` contains `a tenant value asks for the step-up`; if so record Already Applied when its Git blob is 0200e8aee0003948ba129a4bd57a3564b7006bd8, and otherwise stop and report. Otherwise make exactly this one edit (the owner who writes a tenant value is at aal2), each matched once, and change nothing else:

   a) replace the line
   ```text
   select set_config('request.jwt.claims','{"sub":"64000000-0000-0000-0000-0000000000a4"}', true);
   ```
   with
   ```text
   -- The owner is MFA-bound: since Batch 6 slice 51 (`20261114140000`) a tenant value asks for the step-up.
   select set_config('request.jwt.claims','{"sub":"64000000-0000-0000-0000-0000000000a4","aal":"aal2"}', true);
   ```

   The resulting file's Git blob is 0200e8aee0003948ba129a4bd57a3564b7006bd8.

9. Check whether `supabase/tests/92_capability_grant_model_test.sql` contains `an employee is refused MANAGE_PERMISSIONS before the FK is ever reached`; if so record Already Applied when its Git blob is ece170cfd15da7c102001687313d681cbef2917f, and otherwise stop and report. Otherwise make exactly these 8 edits (system-path grant writes clear the leftover claim; the foreign-key proof by the owner at aal2), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
   -- 7-11. INDIVIDUAL GRANT ADDS A CAPABILITY, AND ONLY THAT ONE.
   -- =============================================================================================
   reset role;
   ```
   insert
   ```text
   -- Since Batch 6 slice 51 (`20261114130000`) `app.guard_permission_grant_authority` charges MANAGE_PERMISSIONS to a
   -- signed-in writer, so the leftover claim is CLEARED: every fixture write to it below is a SYSTEM path.
   select set_config('request.jwt.claims', null, true);
   ```

   b) immediately after the lines
   ```text
   -- 12-15. DENY OVERRIDES A ROLE BUNDLE -- the "Finance Manager minus Refund Approval" requirement.
   -- =============================================================================================
   reset role;
   ```
   insert
   ```text
   select set_config('request.jwt.claims', null, true);
   ```

   c) immediately after the lines
   ```text
     'ISOLATION: ...and exactly one capability was removed');

   reset role;
   ```
   insert
   ```text
   select set_config('request.jwt.claims', null, true);
   ```

   d) immediately after the lines
   ```text
   -- 16-18. REVOCATION AND EXPIRY. A capability must be removable, and a lapsed grant must lapse.
   -- =============================================================================================
   reset role;
   ```
   insert
   ```text
   select set_config('request.jwt.claims', null, true);
   ```

   e) immediately after the lines
   ```text
     'REVOKE: deactivating the deny restores the role bundle -- revocation is is_active=false, not a delete');

   reset role;
   ```
   insert
   ```text
   select set_config('request.jwt.claims', null, true);
   ```

   f) replace the lines
   ```text
   -- First, tenant isolation on the new table itself. The session is still acting as TENANT 1's
   -- employee, so `derive_created_by` stamps a tenant-1 actor onto a tenant-2 row -- and the composite
   ```
   with
   ```text
   -- First, tenant isolation on the new table itself. The session acts as TENANT 1's OWNER at aal2 (since
   -- Batch 6 slice 51 an employee is refused MANAGE_PERMISSIONS before the FK is ever reached), so
   -- `derive_created_by` stamps a tenant-1 actor onto a tenant-2 row -- and the composite
   ```

   g) immediately after the lines
   ```text
   -- rather than worked around because the first draft of the statement below hit it for real.
   reset role;
   ```
   insert
   ```text
   select set_config('request.jwt.claims','{"sub":"92000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
   ```

   h) immediately after the lines
   ```text
   --        asserted first, so a mutation that silently did nothing cannot pass as a result.
   -- =============================================================================================
   reset role;
   ```
   insert
   ```text
   select set_config('request.jwt.claims', null, true);
   ```

   The resulting file's Git blob is ece170cfd15da7c102001687313d681cbef2917f.

10. Check whether `supabase/tests/96_invoice_void_and_eta_boundary_test.sql` contains `the fixture grant below is a SYSTEM path`; if so record Already Applied when its Git blob is dfa0b23e384fe29ec369008f4a60b419dc9a3b28, and otherwise stop and report. Otherwise make exactly this one edit (the fixture grant clears the leftover claim), each matched once, and change nothing else:

   a) immediately after the line
   ```text
   -- is granted per-user through RBAC-5's `user_permission_grants`, which also exercises that model.
   ```
   insert
   ```text
   -- Since Batch 6 slice 51 (`20261114130000`) `app.guard_permission_grant_authority` charges MANAGE_PERMISSIONS to a
   -- signed-in writer, so the leftover claim is CLEARED: the fixture grant below is a SYSTEM path.
   select set_config('request.jwt.claims', null, true);
   ```

   The resulting file's Git blob is dfa0b23e384fe29ec369008f4a60b419dc9a3b28.

11. Check whether `supabase/tests/99_role_assignment_temporal_test.sql` contains `the fixture grant below is a SYSTEM path`; if so record Already Applied when its Git blob is 3924adcf334844d94595721823f13082d82b67b2, and otherwise stop and report. Otherwise make exactly these 2 edits (the fixture grant clears the leftover claim), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
   --     the two grant paths back into disagreement from the other direction.
   -- =============================================================================================
   ```
   insert
   ```text
   -- Since Batch 6 slice 51 (`20261114130000`) `app.guard_permission_grant_authority` charges MANAGE_PERMISSIONS to a
   -- signed-in writer, so the leftover claim is CLEARED: the fixture grant below is a SYSTEM path.
   select set_config('request.jwt.claims', null, true);
   ```

   b) immediately after the line
   ```text
   from public.permissions p where p.key = 'MANAGE_MARKETING_CAMPAIGN';
   ```
   insert
   ```text
   select set_config('request.jwt.claims','{"sub":"99000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
   ```

   The resulting file's Git blob is 3924adcf334844d94595721823f13082d82b67b2.

12. Check whether `supabase/tests/101_marketing_metrics_and_fx_adjustment_surface_test.sql` contains `It is no door to that table.`; if so record Already Applied when its Git blob is 9d5f3784082bac2db3f047701c49116c76bb1d74, and otherwise stop and report. Otherwise make exactly this one edit (the rate guard only reads adjustments), each matched once, and change nothing else:

   a) replace the line
   ```text
         and (p.prosrc like '%campaign_daily_metrics%' or p.prosrc like '%exchange_rate_adjustments%')),
   ```
   with
   ```text
         and (p.prosrc like '%campaign_daily_metrics%' or p.prosrc like '%exchange_rate_adjustments%')
         -- Re-reasoned at Batch 6 slice 51 (`20261114120000`): `app.guard_exchange_rate_write` only READS
         -- exchange_rate_adjustments, to refuse rewriting a rate an adjustment cites. It is no door to that table.
         and p.oid <> 'app.guard_exchange_rate_write'::regproc),
   ```

   The resulting file's Git blob is 9d5f3784082bac2db3f047701c49116c76bb1d74.

13. Check whether `supabase/tests/155_an_allocation_spends_its_own_payment_on_its_own_invoice_test.sql` contains `64b. the rate this payment and allocation cite`; if so record Already Applied when its Git blob is d48cccf93cc1b20aa24bf3385704e1e8b712f0eb, and otherwise stop and report. Otherwise make exactly these 3 edits (the cited rate cannot be rewritten (64b, plan 69)), each matched once, and change nothing else:

   a) replace the line
   ```text
   select plan(68);
   ```
   with
   ```text
   select plan(69);
   ```

   b) replace the line
   ```text
     '64. ...and the platform cannot strand a paid invoice either: integrity, not authorization');update public.exchange_rates set rate=0.03 where id='15500000-0000-0000-0000-00000000ee02';
   ```
   with
   ```text
     '64. ...and the platform cannot strand a paid invoice either: integrity, not authorization');
   -- Since Batch 6 slice 51 (`20261114120000`) a rate that recorded money cites cannot be rewritten at all.
   select throws_ok($$update public.exchange_rates set rate=0.03 where id='15500000-0000-0000-0000-00000000ee02'$$,
     '23514','exchange rate 15500000-0000-0000-0000-00000000ee02 is cited by recorded money: set a new rate and record an adjustment',
     '64b. the rate this payment and allocation cite cannot be rewritten under them, by the platform either');
   ```

   c) replace the line
   ```text
     '100.0000/1', '65. after its rate row is edited, touching an allocation without changing its amount changes no money and records nothing');
   ```
   with
   ```text
     '100.0000/1', '65. ...and touching an allocation without changing its amount changes no money and records nothing');
   ```

   The resulting file's Git blob is d48cccf93cc1b20aa24bf3385704e1e8b712f0eb.

14. Check whether `scripts/generate-api-contract.ps1` contains `case when p.prokind='f' then pg_get_functiondef(p.oid) end`; if so record Already Applied when its Git blob is a9e68fd40ca71f23b298ab2429a4abe0184c6028, and otherwise stop and report. Otherwise make exactly these 2 edits (the two trigger-guard reads take a function definition only for a plain function), each matched once, and change nothing else:

   a) replace the lines
   ```text
                             where t.tgrelid=c.oid and not t.tgisinternal and (t.tgtype & 4)<>0
                               and pg_get_functiondef(p.oid) ~ '(app\.authorize|app\.has_permission|app\.require_lead_handler)')
   ```
   with
   ```text
                             where t.tgrelid=c.oid and not t.tgisinternal and (t.tgtype & 4)<>0
                               and case when p.prokind='f' then pg_get_functiondef(p.oid) end ~ '(app\.authorize|app\.has_permission|app\.require_lead_handler)')
   ```

   b) replace the line
   ```text
                               and pg_get_functiondef(p.oid) ~ '(app\.authorize|app\.has_permission|app\.require_lead_handler)')
   ```
   with
   ```text
                               and case when p.prokind='f' then pg_get_functiondef(p.oid) end ~ '(app\.authorize|app\.has_permission|app\.require_lead_handler)')
   ```

   The resulting file's Git blob is a9e68fd40ca71f23b298ab2429a4abe0184c6028.

15. Check whether `_ORVION_CANONICAL/27_event_catalog.md` contains `the old row is recorded leaving effect and the new row taking effect`; if so record Already Applied when its Git blob is 0a78f239febc8960c704a30f44a55517123ec57f, and otherwise stop and report. Otherwise make exactly these 2 edits (the exchange_rate_set and permission event entries: what they record), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
   ## permission_revoked

   Severity: security

   ```
   insert
   ```text
   `permission_granted` and `permission_revoked` are created when a user permission grant takes or leaves effect. When a live grant moves to another user, permission, effect or tenant, the old row is recorded leaving effect and the new row taking effect (RBAC-7, SPEC-307); an edit that changes no effect, such as a reason, records nothing.

   ```

   b) immediately after the lines
   ```text
   ## exchange_rate_set

   Severity: critical

   ```
   insert
   ```text
   Created by every set of a rate and every change of its pair, rate or instant, with the rate id and the previous and current pair, rate and instant; previous is null when the rate is first set, and an update that moves none of them records nothing (FX-5, FX-6, SPEC-307). A rate that recorded money cites is never changed: a new rate is set and an `exchange_rate_adjustments` row records the correction.

   ```

   The resulting file's Git blob is 0a78f239febc8960c704a30f44a55517123ec57f.

16. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `| CAT-9 |`; if so record Already Applied when its Git blob is 069001d4477bf3ec2bddf0d8e8f7858378d29ccc, and otherwise stop and report. Otherwise make exactly these 4 edits (the Slice 51 freshness entry, six new rows, USR-3 closed and the STEPUP-1 note), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-12 (**Slice 50 — `document_links` selected live at Exposure 6, coverage 54; runner-up `exchange_rates` at 6/66.** **DOC-9** (Medium) and **DOC-10** (Low) are new and fixed. A link decides who reads a non-confidential document, and the link's policy checked only its target, so a branch `employee` linked another branch's passport scan or invoice onto their own booking, or re-pointed their own link at it, and read the document and its storage path; a link moved by UPDATE was recorded nowhere. SPEC-306 refuses a link whose document its writer cannot already read and records every move. No other row changed.)
   ```
   with
   ```text
   Last updated: 2026-11-14 (**Slice 51 — `exchange_rates`, `user_permission_grants` and `catalog_values` selected live at Exposure 6, coverage 66, 88 and 102, in one contract (the owner's grouping, 2026-11-14).** **FX-5**, **FX-6**, **RBAC-7** and **CAT-7** (High) and **CAT-8** and **CAT-9** (Medium) are new and fixed, and the last half of **USR-3** is fixed. Rates, permission grants and tenant catalog values were written from password-only sessions; a rate that recorded money cites was rewritten in place; a live grant moved from one user to another unrecorded; a tenant extended platform-owned catalog families and renamed a value under the rows that use it. SPEC-307 charges step-up at all three doors, keeps a cited rate and a used value fixed, and records every rate set and every grant move. STEPUP-1 gains a note. No other row changed.)

   Previously: 2026-11-12 (**Slice 50 — `document_links` selected live at Exposure 6, coverage 54; runner-up `exchange_rates` at 6/66.** **DOC-9** (Medium) and **DOC-10** (Low) are new and fixed. A link decides who reads a non-confidential document, and the link's policy checked only its target, so a branch `employee` linked another branch's passport scan or invoice onto their own booking, or re-pointed their own link at it, and read the document and its storage path; a link moved by UPDATE was recorded nowhere. SPEC-306 refuses a link whose document its writer cannot already read and records every move. No other row changed.)
   ```

   b) immediately after the line
   ```text
   | DOC-10 | **A link moved by UPDATE took a document off the record it belonged to and was recorded nowhere** | audit completeness · observability | Low | R | 6 | M | ✅ | **✅ FIXED 2026-11-12 (SPEC-306, `20261112150000`), DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-306; the fresh Primary ledger, functions and structure equal local.** **MEASURED** at `789e056`: an `employee` moved the ticket link of their booking to another of their bookings; the tenant's events did not move and `app.derive_created_by` keeps the creator, so nothing showed who took the ticket off the booking. A new link is attributed by its own row (`created_by` derived and immutable); `app.upload_document` records `document_linked` for its link. **Repaired:** `app.guard_document_link_readable` (BEFORE INSERT OR UPDATE, SECURITY INVOKER, session writes only) refuses a link whose document the writer cannot already read under the `documents` policy; `app.emit_document_link_move` (AFTER UPDATE, SECURITY DEFINER) records a moved link as `document_linked` with the link id and the previous and current document and target. `165_a_document_is_linked_only_by_someone_who_can_read_it_test.sql` pins both. An update that moves nothing and a session-less write record nothing. | — | SPEC-306-a-document-is-linked-only-by-someone-who-can-read-it | 11-12 | 11-12 |
   ```
   insert
   ```text
   | FX-5 | **A rate that recorded money cites was rewritten in place, re-dated and turned around, so the money it converted changed meaning, and nothing was recorded** | integrity · finance · audit completeness | High | R | 6 | M | 🛡 | **FIXED 2026-11-14 locally (SPEC-307, `20261114120000`); Primary deployment pending.** **MEASURED** at `b44cad9`: a `finance_manager` at `aal2` rewrote a rate that a booking item cites from 48.5 to 99, and a `ceo` re-dated it a year back and turned its pair to EGP to USD. `app.exchange_rate_as_of` then answered 99, `set_by` still named the first setter, and the tenant's events did not move: the registered `exchange_rate_set` was emitted by nothing. `exchange_rate_adjustments` (append-only, `exchange_rate_adjustment_created`) is the designed correction path. **Repaired:** `app.guard_exchange_rate_write` (BEFORE INSERT OR UPDATE, SECURITY DEFINER, empty `search_path`, executable by no client role) first refuses, for every writer, the platform included, any change of tenant, pair, rate or instant of a rate that a booking item, payment, allocation or adjustment cites (23514: set a new rate and record an adjustment), then charges `app.authorize('SET_EXCHANGE_RATE')`, permission and step-up, on every session write; a session-less platform write is exempt from that charge only. `app.emit_exchange_rate_set` (AFTER INSERT OR UPDATE, SECURITY DEFINER) records every set or change as the registered `exchange_rate_set`, critical as canon 27 lists it, with the previous and current pair, rate and instant. `166_an_exchange_rate_is_set_with_step_up_and_keeps_its_meaning_once_cited_test.sql` pins both. A rate nothing cites may still be corrected, and the correction is recorded. | — | SPEC-307-rates-grants-and-catalog-values-change-only-with-step-up-and-a-record | 11-14 | 11-14 |
   | FX-6 | **A finance manager, ceo or owner set exchange rates from a password-only (`aal1`) session** | security · authorization · finance | High | R | 6 | M | 🛡 | **FIXED 2026-11-14 locally (SPEC-307, `20261114120000`); Primary deployment pending.** **MEASURED** at `b44cad9`: the write policy charges `SET_EXCHANGE_RATE` through `app.has_permission`, never the step-up that `app.authorize` charges every role `app.requires_mfa` binds; an `aal1` `finance_manager` set a new rate. The table is a named member of STEPUP-1; this reproduces it with a classified consequence, the rate that money is converted at (FX-5). **Repaired:** `app.guard_exchange_rate_write` (BEFORE INSERT OR UPDATE, SECURITY DEFINER, empty `search_path`, executable by no client role) first refuses, for every writer, the platform included, any change of tenant, pair, rate or instant of a rate that a booking item, payment, allocation or adjustment cites (23514: set a new rate and record an adjustment), then charges `app.authorize('SET_EXCHANGE_RATE')`, permission and step-up, on every session write; a session-less platform write is exempt from that charge only. `app.emit_exchange_rate_set` (AFTER INSERT OR UPDATE, SECURITY DEFINER) records every set or change as the registered `exchange_rate_set`, critical as canon 27 lists it, with the previous and current pair, rate and instant. `166_an_exchange_rate_is_set_with_step_up_and_keeps_its_meaning_once_cited_test.sql` pins both. | — | SPEC-307-rates-grants-and-catalog-values-change-only-with-step-up-and-a-record | 11-14 | 11-14 |
   | RBAC-7 | **A live permission grant was re-pointed to another user or permission, or turned into a deny, and nothing was recorded** | audit completeness · authorization | High | R | 6 | M | 🛡 | **FIXED 2026-11-14 locally (SPEC-307, `20261114130000`); Primary deployment pending.** **MEASURED** at `b44cad9`: a `ceo` at `aal2` re-pointed a live grant from an employee to the finance manager, then to `MANAGE_PERMISSIONS`, then turned it into a deny. `app.emit_permission_change` (RBAC-5, `202607059800`) compared only liveness, which stayed true, so the tenant's events did not move: who gained and who lost a permission was recorded nowhere. **Repaired:** `app.emit_permission_change` now records the old row leaving effect and the new row taking effect whenever a live grant's user, permission, effect or tenant changes (through `app.record_permission_change`, SECURITY DEFINER, executable by no client role), with the same event types, entity, payload and severity as before; an edit that moves no effect, such as a reason, records nothing. `167_a_permission_grant_changes_only_with_step_up_and_every_move_is_recorded_test.sql` pins it. | — | SPEC-307-rates-grants-and-catalog-values-change-only-with-step-up-and-a-record | 11-14 | 11-14 |
   | CAT-7 | **A tenant added its own values to platform-owned catalog families, and its rows could then carry them; a tenant value claimed to be a system value** | integrity · reference data · authorization | High | R | 6 | M | 🛡 | **FIXED 2026-11-14 locally (SPEC-307, `20261114140000`); Primary deployment pending.** **MEASURED** at `b44cad9`: an `owner` at `aal2` added `sideways` to `payment_direction` and `settled9` to `booking_item_base_status`, two of the 67 families whose `catalog_types.ownership_type` is `system`; the write policy reads only the tenant, never the family's ownership, and `app.enforce_catalog_codes` accepts a tenant value of the family on that tenant's rows. Another tenant value was written with `is_system = true`. CAT-2 opened tenant extension; the family's ownership was its unenforced half. **Repaired:** `app.guard_catalog_value_write` (BEFORE INSERT OR UPDATE, SECURITY DEFINER, empty `search_path`, executable by no client role), on every session write: `app.authorize('MANAGE_TENANT_SETTINGS')`, permission and step-up; a value only in one of the four families whose `catalog_types.ownership_type` is `tenant_extendable_system`; never `is_system`; and an UPDATE keeps the value's tenant, family and code (a replaced value is added anew and the old one deactivated, which `app.enforce_catalog_codes` already allows). Label, order and activation stay editable. A session-less platform write is exempt. `168_a_tenant_catalog_value_extends_only_open_families_and_keeps_its_code_test.sql` pins it. | — | SPEC-307-rates-grants-and-catalog-values-change-only-with-step-up-and-a-record | 11-14 | 11-14 |
   | CAT-8 | **A tenant catalog value in use was renamed or moved to another family, leaving the rows that use it holding a code with no value behind it** | integrity · reference data | Medium | R | 6 | M | 🛡 | **FIXED 2026-11-14 locally (SPEC-307, `20261114140000`); Primary deployment pending.** **MEASURED** at `b44cad9`: an `owner` at `aal2` renamed the supplier type `charter9` that a supplier uses, and moved it to `lead_source`; the supplier still held `charter9` and no `supplier_type` value of that code remained (re-measured 2026-11-14 in a rolled-back transaction). Canon 25 deactivates a value and never deletes it; a rename is the same loss. **Repaired:** `app.guard_catalog_value_write` (BEFORE INSERT OR UPDATE, SECURITY DEFINER, empty `search_path`, executable by no client role), on every session write: `app.authorize('MANAGE_TENANT_SETTINGS')`, permission and step-up; a value only in one of the four families whose `catalog_types.ownership_type` is `tenant_extendable_system`; never `is_system`; and an UPDATE keeps the value's tenant, family and code (a replaced value is added anew and the old one deactivated, which `app.enforce_catalog_codes` already allows). Label, order and activation stay editable. A session-less platform write is exempt. `168_a_tenant_catalog_value_extends_only_open_families_and_keeps_its_code_test.sql` pins it. | — | SPEC-307-rates-grants-and-catalog-values-change-only-with-step-up-and-a-record | 11-14 | 11-14 |
   | CAT-9 | **An owner or ceo wrote tenant catalog values from a password-only (`aal1`) session** | security · authorization | Medium | R | 6 | M | 🛡 | **FIXED 2026-11-14 locally (SPEC-307, `20261114140000`); Primary deployment pending.** **MEASURED** at `b44cad9`: the write policy charges `MANAGE_TENANT_SETTINGS` through `app.has_permission`, never the step-up; an `aal1` `owner` added a supplier type. The table is a named member of STEPUP-1; this reproduces it, with CAT-7 and CAT-8 as the consequences a password alone reached. **Repaired:** `app.guard_catalog_value_write` (BEFORE INSERT OR UPDATE, SECURITY DEFINER, empty `search_path`, executable by no client role), on every session write: `app.authorize('MANAGE_TENANT_SETTINGS')`, permission and step-up; a value only in one of the four families whose `catalog_types.ownership_type` is `tenant_extendable_system`; never `is_system`; and an UPDATE keeps the value's tenant, family and code (a replaced value is added anew and the old one deactivated, which `app.enforce_catalog_codes` already allows). Label, order and activation stay editable. A session-less platform write is exempt. `168_a_tenant_catalog_value_extends_only_open_families_and_keeps_its_code_test.sql` pins it. | — | SPEC-307-rates-grants-and-catalog-values-change-only-with-step-up-and-a-record | 11-14 | 11-14 |
   ```

   c) replace the line
   ```text
   | USR-3 | **`user_permission_grants` and `user_branch_assignments` charge no step-up at the table door — a `ceo` at `aal1` self-granted a permission and self-assigned a branch** | security · authorization | High | R | 6 | — | 📋 | **OPEN — the `user_permission_grants` half only.** The `user_branch_assignments` half FIXED 2026-11-11 (SPEC-300, `20261111120000`) and DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-300. `app.guard_placement_authority` (BEFORE INSERT OR UPDATE, SECURITY DEFINER, empty `search_path`, executable by no client role) charges `app.authorize('MANAGE_USERS')`, permission AND step-up, on every session write and every column, as `app.assign_user_branch` does; a session-less platform write is exempt, as in every sibling guard. Re-measured at `90a3a72` before the repair: the `aal1` `ceo` was refused by the RPC, then added a branch by direct INSERT and moved a colleague's primary from one branch and department to another by direct UPDATE; after it, both direct writes are refused 42501. Pinned by `160_...` assertions 3-4 and 15 and mutant M1 (the guard dropped), killed; `10_...` MEAS-2 now counts twelve bespoke-guard tables. The permission-grant half below is unchanged. Original text follows. **OPEN — a DIFFERENT SURFACE, deliberately not absorbed (Batch 6 slice 12).** MEASURED: a `ceo` at `aal1` self-granted `VIEW_ADVANCED_DASHBOARDS` on `public.user_permission_grants`, moving `app.has_permission` for it from false to **true**, and self-assigned an additional branch on `public.user_branch_assignments`. The same actor at the same `aal1` was refused `42501` on `public.user_role_assignments`, which is what makes these OUTLIERS rather than the norm — the precedent works, and these two tables are simply not behind it. **One precision that must not be lost:** the permission-grant door DID emit an event, so this gap is **step-up only, not audit** — the opposite balance from USR-1/USR-2, and a repairer who copies SPEC-203 wholesale would add an emitter that duplicates an existing one. **Not repaired here, and the boundary is mechanical, not rhetorical:** these are separate surfaces with their own defining migration (`202607059800`), which SPEC-203 names in its frozen Out of Scope. Widening a slice to absorb a neighbouring defect is what four cancelled predecessors did wrong. **Reopening trigger:** the next Batch-6 slice that selects either table, or any change to `202607059800` | — | SPEC-203-membership-authority-and-audit | 09-20 | 11-11 |
   ```
   with
   ```text
   | USR-3 | **`user_permission_grants` and `user_branch_assignments` charge no step-up at the table door — a `ceo` at `aal1` self-granted a permission and self-assigned a branch** | security · authorization | High | R | 6 | — | 🛡 | **FIXED 2026-11-14 locally (SPEC-307, `20261114130000`); Primary deployment pending.** **Both halves are now closed.** The `user_permission_grants` half: `app.guard_permission_grant_authority` (BEFORE INSERT OR UPDATE, SECURITY DEFINER, empty `search_path`, executable by no client role) charges `app.authorize('MANAGE_PERMISSIONS')`, permission and step-up, on every session write and every column, as SPEC-300 did for placements; a session-less platform write is exempt. Re-measured at `b44cad9` before the repair: the `aal1` `ceo` granted itself `VIEW_ADVANCED_DASHBOARDS` (the grant was recorded, as this row says); after it, the same write is refused 42501. Pinned by `167_a_permission_grant_changes_only_with_step_up_and_every_move_is_recorded_test.sql` and its mutants M1 and M2, killed; `10_grant_model_test.sql` MEAS-2 now counts seventeen bespoke-guard tables. The moves the grant emitter missed are RBAC-7. Earlier text follows. **OPEN — the `user_permission_grants` half only.** The `user_branch_assignments` half FIXED 2026-11-11 (SPEC-300, `20261111120000`) and DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-300. `app.guard_placement_authority` (BEFORE INSERT OR UPDATE, SECURITY DEFINER, empty `search_path`, executable by no client role) charges `app.authorize('MANAGE_USERS')`, permission AND step-up, on every session write and every column, as `app.assign_user_branch` does; a session-less platform write is exempt, as in every sibling guard. Re-measured at `90a3a72` before the repair: the `aal1` `ceo` was refused by the RPC, then added a branch by direct INSERT and moved a colleague's primary from one branch and department to another by direct UPDATE; after it, both direct writes are refused 42501. Pinned by `160_...` assertions 3-4 and 15 and mutant M1 (the guard dropped), killed; `10_...` MEAS-2 now counted twelve bespoke-guard tables. Original text follows. **OPEN — a DIFFERENT SURFACE, deliberately not absorbed (Batch 6 slice 12).** MEASURED: a `ceo` at `aal1` self-granted `VIEW_ADVANCED_DASHBOARDS` on `public.user_permission_grants`, moving `app.has_permission` for it from false to **true**, and self-assigned an additional branch on `public.user_branch_assignments`. The same actor at the same `aal1` was refused `42501` on `public.user_role_assignments`, which is what makes these OUTLIERS rather than the norm — the precedent works, and these two tables are simply not behind it. **One precision that must not be lost:** the permission-grant door DID emit an event, so this gap is **step-up only, not audit** — the opposite balance from USR-1/USR-2, and a repairer who copies SPEC-203 wholesale would add an emitter that duplicates an existing one. **Not repaired here, and the boundary is mechanical, not rhetorical:** these are separate surfaces with their own defining migration (`202607059800`), which SPEC-203 names in its frozen Out of Scope. Widening a slice to absorb a neighbouring defect is what four cancelled predecessors did wrong. **Reopening trigger:** the next Batch-6 slice that selects either table, or any change to `202607059800` | — | SPEC-203-membership-authority-and-audit | 09-20 | 11-14 |
   ```

   d) replace the line
   ```text
   | STEPUP-1 | **A class CANDIDATE, found by structural evidence: eleven tables carry a direct permission-only write path with no step-up anywhere in their trigger chain** | security · authorization · class | Unclassified | R | 6 | — | 📋 | **UNPROVEN — structural candidate class, recorded, deliberately not acted on (Batch 6 Slice 24).** Not a reproduced class defect. Criterion, read from the local catalog at `b6a0714`: `authenticated` holds INSERT or UPDATE; the INSERT or UPDATE policy charges `app.has_permission(K)` for a K held only by roles that `app.requires_mfa` binds to step-up; and no trigger on the table, at any timing, calls `app.authorize` or `app.mfa_satisfied` directly or through one level of `app` helper. Eleven tables meet it: `branches`, `campaign_daily_metrics`, `catalog_values`, `chart_of_accounts`, `departments`, `document_retention_policies`, `exchange_rate_adjustments`, `exchange_rates`, `journal_entries`, `journal_entry_lines`, `tenants`. `user_branch_assignments` and `user_permission_grants` meet it too and belong to USR-3. `user_role_assignments` does NOT: its AFTER trigger `app.emit_role_change` charges `app.authorize('MANAGE_USERS')`, which a first, BEFORE-only reading missed and a rolled-back probe corrected. **Only `branches` is a reproduced and consequence-classified defect (BRANCH-1, Low).** **`journal_entry_lines` was audited in Batch 6 Slice 32 (SPEC-245): an `aal1` finance manager rewrote posted lines the RPC refuses it to post, and that member is closed by JE-3's repair; it no longer meets the criterion, because `authenticated` holds no INSERT or UPDATE on it. `chart_of_accounts` was audited in Batch 6 Slice 42 (SPEC-278): its member was reproduced as COA-2 and is closed, and it no longer meets the criterion, because `app.guard_chart_account` charges `app.authorize`. `journal_entries` still meets it (JE-5).** The same probe saw an `aal1` owner's rename land on `departments` and on `tenants`. `departments`' consequence is not classified, so it remains a candidate and is not an audit. **`tenants` was audited in Batch 6 Slice 26 (SPEC-228) and its consequence is classified: none material.** An `aal1` `owner` or `ceo` does write every tenant-profile column, but nothing reads any of them except `name`, shown only to the tenant's own members; no canon marks a tenant-profile edit as step-up, platform-only or sensitive; and the other MANAGE_TENANT_SETTINGS doors that charge `app.authorize` guard distinct actions (licence redemption, payment-proof upload, legal hold, document versions and links, holidays), not a second door to the same action. So `tenants` still meets the criterion, is not a defect, and does not raise this class above UNPROVEN. The other eight are structural candidates only; the finance tables among them are where a consequence, if reproduced, would most likely be material. A member becomes a defect only when it is individually reproduced adversarially and its consequence is classified, and no member gains a disposition or counts toward Batch 6 coverage by being listed here. `campaign_daily_metrics` and `exchange_rate_adjustments` are recorded `AUDITED`, and step-up was not asked on either. **Ceiling:** the criterion reads function text, so it can miss step-up charged through deeper indirection and it cannot see consequence (MEAS-1). **Trigger to revisit:** the Batch 6 slice of any listed table, or the first reproduced consequence on a candidate. **2026-10-08 (SPEC-246): `journal_entries` no longer meets the criterion, because `authenticated` holds no INSERT or UPDATE on it; its member consequence, JE-5, is closed by that revoke.** **2026-11-11 (SPEC-301): `departments` was audited in Batch 6 Slice 46; its member was reproduced as DEP-1 with a classified consequence (DEP-3) and is closed, and it no longer meets the criterion, because `app.guard_department_write` charges `app.authorize`.** **2026-11-11 (SPEC-305): `document_retention_policies` was audited in Batch 6 Slice 49; its member was reproduced as RET-3 with a classified consequence (a superseded file made deletable at `aal1`) and is closed, and it no longer meets the criterion, because `app.guard_document_retention_policy_write` charges `app.authorize`.** | — | SPEC-226-branch-door-audit-record | 09-27 | 09-27 |
   ```
   with
   ```text
   | STEPUP-1 | **A class CANDIDATE, found by structural evidence: eleven tables carry a direct permission-only write path with no step-up anywhere in their trigger chain** | security · authorization · class | Unclassified | R | 6 | — | 📋 | **UNPROVEN — structural candidate class, recorded, deliberately not acted on (Batch 6 Slice 24).** Not a reproduced class defect. Criterion, read from the local catalog at `b6a0714`: `authenticated` holds INSERT or UPDATE; the INSERT or UPDATE policy charges `app.has_permission(K)` for a K held only by roles that `app.requires_mfa` binds to step-up; and no trigger on the table, at any timing, calls `app.authorize` or `app.mfa_satisfied` directly or through one level of `app` helper. Eleven tables meet it: `branches`, `campaign_daily_metrics`, `catalog_values`, `chart_of_accounts`, `departments`, `document_retention_policies`, `exchange_rate_adjustments`, `exchange_rates`, `journal_entries`, `journal_entry_lines`, `tenants`. `user_branch_assignments` and `user_permission_grants` meet it too and belong to USR-3. `user_role_assignments` does NOT: its AFTER trigger `app.emit_role_change` charges `app.authorize('MANAGE_USERS')`, which a first, BEFORE-only reading missed and a rolled-back probe corrected. **Only `branches` is a reproduced and consequence-classified defect (BRANCH-1, Low).** **`journal_entry_lines` was audited in Batch 6 Slice 32 (SPEC-245): an `aal1` finance manager rewrote posted lines the RPC refuses it to post, and that member is closed by JE-3's repair; it no longer meets the criterion, because `authenticated` holds no INSERT or UPDATE on it. `chart_of_accounts` was audited in Batch 6 Slice 42 (SPEC-278): its member was reproduced as COA-2 and is closed, and it no longer meets the criterion, because `app.guard_chart_account` charges `app.authorize`. `journal_entries` still meets it (JE-5).** The same probe saw an `aal1` owner's rename land on `departments` and on `tenants`. `departments`' consequence is not classified, so it remains a candidate and is not an audit. **`tenants` was audited in Batch 6 Slice 26 (SPEC-228) and its consequence is classified: none material.** An `aal1` `owner` or `ceo` does write every tenant-profile column, but nothing reads any of them except `name`, shown only to the tenant's own members; no canon marks a tenant-profile edit as step-up, platform-only or sensitive; and the other MANAGE_TENANT_SETTINGS doors that charge `app.authorize` guard distinct actions (licence redemption, payment-proof upload, legal hold, document versions and links, holidays), not a second door to the same action. So `tenants` still meets the criterion, is not a defect, and does not raise this class above UNPROVEN. The other eight are structural candidates only; the finance tables among them are where a consequence, if reproduced, would most likely be material. A member becomes a defect only when it is individually reproduced adversarially and its consequence is classified, and no member gains a disposition or counts toward Batch 6 coverage by being listed here. `campaign_daily_metrics` and `exchange_rate_adjustments` are recorded `AUDITED`, and step-up was not asked on either. **Ceiling:** the criterion reads function text, so it can miss step-up charged through deeper indirection and it cannot see consequence (MEAS-1). **Trigger to revisit:** the Batch 6 slice of any listed table, or the first reproduced consequence on a candidate. **2026-10-08 (SPEC-246): `journal_entries` no longer meets the criterion, because `authenticated` holds no INSERT or UPDATE on it; its member consequence, JE-5, is closed by that revoke.** **2026-11-11 (SPEC-301): `departments` was audited in Batch 6 Slice 46; its member was reproduced as DEP-1 with a classified consequence (DEP-3) and is closed, and it no longer meets the criterion, because `app.guard_department_write` charges `app.authorize`.** **2026-11-11 (SPEC-305): `document_retention_policies` was audited in Batch 6 Slice 49; its member was reproduced as RET-3 with a classified consequence (a superseded file made deletable at `aal1`) and is closed, and it no longer meets the criterion, because `app.guard_document_retention_policy_write` charges `app.authorize`.** **2026-11-14 (SPEC-307): `exchange_rates` and `catalog_values` were audited in Batch 6 Slice 51; each member was reproduced with a classified consequence (FX-6 with FX-5: an `aal1` finance manager set the rate money is converted at; CAT-9 with CAT-7 and CAT-8: an `aal1` owner extended platform-owned families and renamed a value in use) and is closed, and neither meets the criterion any more, because `app.guard_exchange_rate_write` and `app.guard_catalog_value_write` charge `app.authorize`. `user_permission_grants` no longer meets it either: USR-3 is closed by `app.guard_permission_grant_authority`.** | — | SPEC-226-branch-door-audit-record | 09-27 | 09-27 |
   ```

   The resulting file's Git blob is 069001d4477bf3ec2bddf0d8e8f7858378d29ccc.

17. Check whether `reports/master/MASTER_SURFACE_DISPOSITION.md` contains `**54 of 78 recorded · 30 `; if so record Already Applied when its Git blob is 415a82bc414669369fd7647ca163c5df0cb467f4, and otherwise stop and report. Otherwise make exactly these 6 edits (the freshness entry, coverage 54 of 78 and the three surface rows), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-12 (**slice 50 — `document_links` selected by Exposure 6, coverage 54; runner-up `exchange_rates` at 6/66.** Coverage **50 → 51 of 78**. DOC-9: a branch employee linked another branch's document onto their own booking and read it. DOC-10: a moved link was recorded nowhere. SPEC-306 closes both here, so the row is `AUDITED`.)
   ```
   with
   ```text
   Last updated: 2026-11-14 (**slice 51 — `exchange_rates`, `user_permission_grants` and `catalog_values` selected by Exposure 6, coverage 66, 88 and 102, in one contract.** Coverage **51 → 54 of 78**. FX-5 and FX-6: a rate that recorded money cites was rewritten in place, and rates were set from password-only sessions. USR-3 and RBAC-7: grants were written from password-only sessions, and a live grant moved between users unrecorded. CAT-7, CAT-8 and CAT-9: a tenant extended platform-owned families, renamed a value in use, and wrote values from password-only sessions. SPEC-307 closes all of them here, so the three rows are `AUDITED`.)

   Previously: 2026-11-12 (**slice 50 — `document_links` selected by Exposure 6, coverage 54; runner-up `exchange_rates` at 6/66.** Coverage **50 → 51 of 78**. DOC-9: a branch employee linked another branch's document onto their own booking and read it. DOC-10: a moved link was recorded nowhere. SPEC-306 closes both here, so the row is `AUDITED`.)
   ```

   b) replace the line
   ```text
   **51 of 78 recorded · 27 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 27 `NOT-RECORDED`.**
   ```
   with
   ```text
   **54 of 78 recorded · 30 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 24 `NOT-RECORDED`.**
   ```

   c) replace the line
   ```text
   **All 51 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```
   with
   ```text
   **All 54 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```

   d) replace the line
   ```text
   | `catalog_values` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `catalog_values` | **AUDITED** | ADVERSARIAL | `SPEC-307-rates-grants-and-catalog-values-change-only-with-step-up-and-a-record` | CAT-7, CAT-8, CAT-9 | `168_a_tenant_catalog_value_extends_only_open_families_and_keeps_its_code_test.sql` (11 assertions, ten attack classes declared, TENANT, STATE, CONCURRENCY, REPLAY and OBSERVABILITY N/A) proves that an owner adds a tenant value only at `aal2`, only to a family open to tenants, never as a system value; that a value keeps its family and code while its label and activation stay editable, so the supplier using it still finds it; that an employee is refused; and that a session-less platform write lands. Test 64 (its owner now at `aal2`) moved for that reason; 07, 08, 11, 12, 15, 22, 25, 35, 42, 47, 93, 100, 104, 106, 114 and 115 pass unchanged. **Swept and classified as non-defects:** global values stay read-only to tenants (the unchanged policies); no DELETE grant. **Recorded position:** a tenant value's label, order or activation change is not recorded (a tenant setting; no event type is added). 0 hosted tenant values; the 626 global values are unchanged. |
   ```

   e) replace the line
   ```text
   | `exchange_rates` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `exchange_rates` | **AUDITED** | ADVERSARIAL | `SPEC-307-rates-grants-and-catalog-values-change-only-with-step-up-and-a-record` | FX-5, FX-6 | `166_an_exchange_rate_is_set_with_step_up_and_keeps_its_meaning_once_cited_test.sql` (12 assertions, ten attack classes declared, TENANT, STATE, CONCURRENCY and REPLAY N/A) proves that a finance manager sets a rate only at `aal2` and an employee without `SET_EXCHANGE_RATE` is refused; that a rate a booking item cites cannot be rewritten, re-dated or turned around by any writer, the platform included, while a rate nothing cites may still be corrected; that every set and correction is recorded once as `exchange_rate_set` (critical) with the previous and current values; and that a session-less platform write sets a rate. Tests 101 (the rate guard only reads adjustments) and 155 (64b: the cited rate's rewrite is refused) moved for those reasons; 26, 29, 39, 83, 95, 98, 106, 113 and 126 pass unchanged. **Swept and classified as non-defects:** another tenant reads no rate (the scope policies); no DELETE grant; an employee is refused by RLS. 0 hosted rates. |
   ```

   f) replace the line
   ```text
   | `user_permission_grants` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `user_permission_grants` | **AUDITED** | ADVERSARIAL | `SPEC-307-rates-grants-and-catalog-values-change-only-with-step-up-and-a-record` | USR-3, RBAC-7 | `167_a_permission_grant_changes_only_with_step_up_and_every_move_is_recorded_test.sql` (10 assertions, ten attack classes declared, TENANT, STATE, INPUT, CONCURRENCY, REPLAY and BUSINESS N/A) proves that a ceo grants only at `aal2` and an employee cannot grant itself `MANAGE_PERMISSIONS`; that a live grant moved to another user is recorded as revoked from the first and granted to the second, a grant turned into a deny as the grant leaving and the deny taking effect, and a reason edit records nothing; and that a session-less platform write lands. Tests 10 (MEAS-2: seventeen tables), 92, 96 and 99 (a leftover claim cleared before a system-path grant write, as test 38 since SPEC-300; test 92's foreign-key proof by the owner at `aal2`) moved for those reasons; 35, 83, 98, 103, 106, 116, 120, 126, 131, 134, 141 and 150 pass unchanged. **Swept and classified as non-defects:** an employee is refused by RLS; the platform-permission guard (SUB-3) is unchanged. **Recorded positions:** `created_at` is caller-supplied on INSERT and read by nothing that decides (SPEC-216's schema-wide question); the grant events keep the `warning` severity they have carried since `202607059800`, where canon 27 lists `security`. 0 hosted grants. |
   ```

   The resulting file's Git blob is 415a82bc414669369fd7647ca163c5df0cb467f4.

18. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, with Steps 1–17 applied and uncommitted in the main checkout, run with the project-local CLI and record, with actual counts, exits and exact SHA-256 values:
   - the SHA-256, md5 and byte counts of the three migrations and tests 166, 167 and 168, which must equal Consumer Closure;
   - on the local stack holding the migrations: the six functions' `md5(prosrc)`, security mode and ACL, the triggers of the three tables, and the catalog count; tests 166, 167 and 168 and the seven moved tests alone; the probes; the thirteen mutants, the restored shape proven equal;
   - the causal negatives, and the stack before the migrations, then the stack restored with them;
   - the local structural fingerprints of `scripts/parity_surface.sql`, before and after the migrations;
   - the API-contract generator, whose output must differ from `MASTER_API_CONTRACT.md` only in the three rows of Consumer Closure; the map generator, the scope check and `git diff --check`.

   Treat as expected at this boundary only: an undeployed Primary, the three moved API-contract rows and the measured-state items of Consumer Closure.

   Read a fresh Primary baseline, read-only: the project URL, the full ordered ledger and the absence of the three target migrations; the function and structural surfaces; the triggers of the three tables and the absence of the five new functions; the tenant, rate, grant, catalog value and event counts. Record the predicted delta. If any reading differs, stop.
19. **Check** that an exact-SHA Gate-2 record for the three migrations is in the Execution Log: the owner's own, or one marked DELEGATED naming this contract, each migration's SHA-256, Primary `vrvtsxexkiiiivlkdxzp` and the owner's instructions under which it is taken. If absent, write it only when Step 18 passed and those instructions cover migrations that drop no table or column and delete or rewrite no business row; otherwise stop after Step 18 and present the Gate-2 package.
20. **Check** which of `20261114120000_an_exchange_rate_is_set_with_step_up_and_keeps_its_meaning_once_cited`, `20261114130000_a_permission_grant_changes_only_with_step_up_and_every_move_is_recorded` and `20261114140000_a_tenant_catalog_value_extends_only_open_families_and_keeps_its_code` Primary `vrvtsxexkiiiivlkdxzp` lacks. If Step 19 is recorded, for each one it lacks, in version order:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, the target's absence, the business counts and the triggers of the three tables.
   - On an exact match, prove the transmitted text's md5 server-side, then apply only that migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row other than this contract's own versions, its stored statement md5 equal to the file's, and no existing target version.

   Then read fresh: the ledger, the function surface and all ten structural surfaces; the triggers of the three tables; the six functions' `md5(prosrc)`, security mode and ACL; the business counts. Never contact Secondary `brplkqmbzffpxqgkkdzo`.
21. **Check** that fresh Primary evidence contains each of the three new migrations exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with the client RPC figure unchanged.
   - Confirm that `supabase/tests` holds 168 files whose literal `plan(N)` values sum to 3151, then set `Suite **168 files / 3151 assertions**`. If either differs, stop.
   - In the register, replace each `` | 🛡 | **FIXED 2026-11-14 locally (SPEC-307, `V`); Primary deployment pending.** `` with `` | ✅ | **✅ FIXED 2026-11-14 (SPEC-307, `V`), DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-307; the fresh Primary ledger, functions and structure equal local.** ``, for V `20261114120000` (the two rows FX-5 and FX-6), `20261114130000` (USR-3 and RBAC-7) and `20261114140000` (CAT-7, CAT-8 and CAT-9). Each span's one leading and one trailing space are delimiters, not text. Change nothing else in the register.
   - Regenerate `MASTER_API_CONTRACT.md`, which must change only in the three rows of Consumer Closure, and `ai-map.json` and `repository-index.md` (stored LF) with the canonical generators.
   - Set the Runtime Checkpoint to DONE, append the Execution Log, and commit the implementation once; the pre-commit Gate must admit it.

   If Primary is unproven, stop.
22. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `-Finish` through `scripts/run_timed.ps1`, watched by `scripts/watch_run.ps1`, and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, in the Complete commit: transition to Complete, tick the Acceptance Criteria and the Review Gate, clear `Active Change Request`, set `Last Completed` from Notes, leave `Next capability` and `Current Module` unchanged, and regenerate `ai-map.json` and `repository-index.md` LF.
   - Bind the exact candidate with `-Gate -BindCandidate`. Publication and promotion follow the native release path separately.

## Acceptance Criteria

- [ ] The rate migration is the frozen bytes; `check: blob supabase/migrations/20261114120000_an_exchange_rate_is_set_with_step_up_and_keeps_its_meaning_once_cited.sql 2bd89afb09e54e94b067557baf03bfc62cdc30ee`
- [ ] The grant migration is the frozen bytes; `check: blob supabase/migrations/20261114130000_a_permission_grant_changes_only_with_step_up_and_every_move_is_recorded.sql fe62f40f4df3636db6693837564e84fc7a246a23`
- [ ] The catalog value migration is the frozen bytes; `check: blob supabase/migrations/20261114140000_a_tenant_catalog_value_extends_only_open_families_and_keeps_its_code.sql e0678f33c8e458b74af66f8e93ae1b7fc3300504`
- [ ] Test 166 is the frozen bytes; `check: blob supabase/tests/166_an_exchange_rate_is_set_with_step_up_and_keeps_its_meaning_once_cited_test.sql ea86cc11ed685a1306cd6ad19eef21d6961a5f00`
- [ ] Test 167 is the frozen bytes; `check: blob supabase/tests/167_a_permission_grant_changes_only_with_step_up_and_every_move_is_recorded_test.sql 286d02370f03aa8f9dc63df55ab60e626d1cf15c`
- [ ] Test 168 is the frozen bytes; `check: blob supabase/tests/168_a_tenant_catalog_value_extends_only_open_families_and_keeps_its_code_test.sql 2fd246de59157743388bc55f7e94172e17899a7a`
- [ ] Canon 27 says what the grant events now also record; `check: has _ORVION_CANONICAL/27_event_catalog.md "the old row is recorded leaving effect and the new row taking effect"`
- [ ] The disposition record carries the three surfaces AUDITED / ADVERSARIAL and coverage 54 of 78; `check: blob reports/master/MASTER_SURFACE_DISPOSITION.md 415a82bc414669369fd7647ca163c5df0cb467f4`
- [ ] The seven register rows are fixed and deployed; `check: has reports/master/MASTER_GAP_REGISTER.md "DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-307"`
- [ ] The manifest suite figure equals the files; `check: has _ORVION_CANONICAL/manifest.md "Suite **168 files / 3151 assertions**"`
- [ ] Native evaluator remains exact; `check: same scripts/check_agent_continuity.ps1 @b44cad9e8d9cad1889b91e62e72430960649f01f`
- [ ] The step-up authority remains exact; `check: same supabase/migrations/202607044100_mfa_requirement_enforcement.sql @b44cad9e8d9cad1889b91e62e72430960649f01f`
- [ ] The smoke catalog count remains exact; `check: same scripts/verify_database.sql @b44cad9e8d9cad1889b91e62e72430960649f01f`
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the three authorized migrations and at most one guarded ledger rename for each, with no business-data write, after a recorded Step 18 readiness gate and Step 19 Gate-2 record; Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] The thirteen mutants are each killed with installation proven and the restored shape read, and the three causal negatives are recorded.

## Execution Log

None.

## Verification Notes

None.


### 2026-11-14 — Gate 1 approval recorded

DELEGATED exact Gate1 under the owner's instructions of 2026-11-08 (class authorization for Batch 6 releases and standing approval of proposals ~10:20 Cairo; publish, promote and hosted deploy ~12:05 Cairo), 2026-11-11 (Batch 6 decisions 1-9 ~19:50 Cairo), 2026-11-12 (priority order waiving no gate ~12:20 Cairo) and 2026-11-14 (one contract per product, generator correction, slice 9 in run mode 2 ~11:30 Cairo; no credential rotation ~12:30 Cairo); Draft SHA-256 7990BCC82CDA3D62DFED2C34DBE15BE9AB8E3A1898AF93D437AB0BEB42D5679B, decision SHA-256 D781E03A24DC06B6B5623D23AC62600F5C595DBF5EBD02332D2C8434E1DA08D3. No fabricated human future-digest approval. Gate 2 (Primary deploy) is a separate exact-SHA record in Step 19. Immediately before allocation the hash, the Draft blob acd5d984ffb0371137d7e1d5846929a6bb605dd2, all 11 source anchors, the baseline HEAD b44cad9e8d9cad1889b91e62e72430960649f01f against refreshed origin/main b44cad9e8d9cad1889b91e62e72430960649f01f and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 61e8da7. No implementation performed before this transition.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

After actual native Finish and truthful Review, synchronize only this contract and the declared manifest/discovery paths to Complete. Set `Last Completed: **SPEC-307: Batch 6 Slice 51 — exchange rates, permission grants and tenant catalog values change only with step-up; a cited rate and a used catalog code keep their meaning; every rate set and grant move is recorded (FX-5, FX-6, USR-3, RBAC-7, CAT-7, CAT-8, CAT-9), deployed to Primary; native verification and Review complete. Publication/promotion remain separately governed.**` and regenerate discovery. `Next capability` and `Current Module` stay unchanged: the selector names the next slice. Candidate binding follows Complete and is never a pre-Complete criterion.

Exact baseline b44cad9e8d9cad1889b91e62e72430960649f01f and source anchors:

| Path | Baseline Git blob |
| --- | --- |
| `supabase/tests/10_grant_model_test.sql` | `10c10ed1fbd8fa0d32e1f3daa59dc86cfc53ee8f` |
| `supabase/tests/64_acquisition_lineage_test.sql` | `1093bbfb114a048860d76490820631ff773e1d12` |
| `supabase/tests/92_capability_grant_model_test.sql` | `4377b08f760deb7f3c3f1bd324a5d8eace9f0853` |
| `supabase/tests/96_invoice_void_and_eta_boundary_test.sql` | `cb4bfd6413c7ff6d05104a174d13dc5b97c7c468` |
| `supabase/tests/99_role_assignment_temporal_test.sql` | `00a89a03ad412ae26c5dd60c6e66d2eb4d414555` |
| `supabase/tests/101_marketing_metrics_and_fx_adjustment_surface_test.sql` | `25c7145a199997a4ddb2479228709f1433556dba` |
| `supabase/tests/155_an_allocation_spends_its_own_payment_on_its_own_invoice_test.sql` | `d61d97f1c0a84965901db5fcdf3bc653b3940b63` |
| `scripts/generate-api-contract.ps1` | `8d7d1a7a4ec871745c2ecd2c03115496a772d030` |
| `_ORVION_CANONICAL/27_event_catalog.md` | `609c2a90947eb29b7e56ca7aa5ceecfd2832ae98` |
| `reports/master/MASTER_GAP_REGISTER.md` | `c58a2307bc82aa343e145ab8000cf97b105dc7ec` |
| `reports/master/MASTER_SURFACE_DISPOSITION.md` | `57392a42d2d6879b77c0d2016cb10e1735028afc` |

Selection sources: native AGENTS.md, CR_LIFECYCLE.md, ENGINEERING_METHOD.md, SPEC-300 and SPEC-306 at b44cad9e8d9cad1889b91e62e72430960649f01f; the owner's instructions of 2026-11-08 and 2026-11-14 (recorded outside this repository). This is the one Draft for these surfaces, finalized after the adversarial review and the evidence refresh its Draft Assurance records; correctness remains native and independent.
