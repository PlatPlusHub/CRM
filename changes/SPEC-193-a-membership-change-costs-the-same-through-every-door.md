# Change Request — SPEC-193

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[x] Cancelled

## Objective

Give `public.users` a path-independent membership boundary: every membership creation, activation change and identity re-binding costs the same step-up and reaches the audit spine whether it is reached through `app.create_tenant_user` or through direct DML, while `app.activate_membership()` self-claim and session-less platform provisioning keep working exactly as they do today.

## Business Reason

`public.users` is the row that decides who exists in a tenant, whether they can act, and which human holds their roles. Batch 6 Slice 12 selected it by exposure (15, first eligible, `NOT-RECORDED`) and two defects were reproduced against a clean local baseline:

- **USR-1** — a `MANAGE_USERS` holder can create a membership, deactivate a colleague, or re-point a role-bearing membership onto a different human, and the audit spine records nothing. `user_created` exists only because `create_tenant_user` calls `record_event` inside the function, which is exactly the RPC-only-producer shape `202607055100` removed from `assign_user_role`. `users` is the only member of the identity-and-access family (`user_role_assignments`, `user_permission_grants`, `user_branch_assignments`) with no emitter at all.
- **USR-2** — the same administrative act costs a step-up through the RPC and nothing through direct DML. `app.create_tenant_user` calls `app.authorize('MANAGE_USERS')` (permission **and** MFA); RLS on the table calls `app.has_permission('MANAGE_USERS')` (permission only). `app.emit_role_change` already states the rule this violates, verbatim: *"`authorize`, not `has_permission`: this is what removes consequence 3. Changing who holds a role now costs the same step-up through direct DML as it does through the RPC."*

Closing these also closes **IDENT-2** (the membership claim emits no event), because the claim moves the same `auth_user_id` column the new emitter observes. That is recorded here rather than left as an accidental side effect.

## Risks

- **Breaking legitimate onboarding is the main risk, and it is the reason this is not a copy of the sibling trigger.** A trigger that charged `authorize('MANAGE_USERS')` on every session-backed write would make `activate_membership()` impossible for an ordinary employee. Measured: inside an AFTER trigger during self-claim, `auth.uid()` is the claimant and `has_permission('MANAGE_USERS')` is **false** for an `employee` claimant and **true** for a `ceo` claimant — so a regression test written with a CEO fixture would go green while every ordinary employee was locked out. The self-claim carve-out and a mandatory employee-claimant regression test both exist for this.
- **Trigger timing is load-bearing.** The authority check is a precondition and must run BEFORE; the record is a fact and must run AFTER. Measured: an AFTER-only check refuses an administrator deactivating their own membership (`permission denied: MANAGE_USERS`), because `users.is_active` is an input to the very permission resolution the check depends on. Splitting the two is required by evidence, not preference.
- **Blast radius across the suite is real but enumerated.** A prototype was applied out of band and the full pgTAP suite run before this Change Request was written; exactly three assertions move, and all three are in Write Scope. The prototype was removed by `npx supabase db reset` and the repository baseline re-proved before authoring.
- Adding three event codes widens vocabulary. Mitigated by keeping it to the smallest set that can truthfully name the measured transitions, and by registering them in the canonical catalog `app.record_event`'s own error message names as the authority.
- Not repairing leaves an administrator able to transfer a CEO membership to another human with no trace and no step-up — measured to yield `APPROVE_FINANCE`, `VIEW_FINANCIAL_DOCUMENTS` and `MANAGE_USERS` on the receiving identity.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-193-a-membership-change-costs-the-same-through-every-door.md`
- `ai-map.json`
- `supabase/migrations/20260917120000_a_membership_change_costs_the_same_through_every_door.sql`
- `supabase/tests/118_membership_authority_and_audit_test.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/35_subscription_write_gate_test.sql`
- `supabase/tests/75_human_identity_family_test.sql`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/manifest.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/README.md`
- `reports/history/session-2026-09-17-batch6-slice12-users.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607055100_role_change_audit_and_cursor_authority.sql`
- `supabase/migrations/202607057800_an_unverified_email_is_not_proof_of_identity.sql`
- `supabase/migrations/202607058000_a_membership_may_not_claim_a_different_human.sql`
- `supabase/migrations/202607049600_identity_event_emission.sql`
- `supabase/tests/51_role_change_audit_test.sql`
- `supabase/tests/57_write_capability_map_test.sql`
- `supabase/tests/76_tenant_administration_test.sql`
- `scripts/check_agent_continuity.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/verify_database.sql`
- `AGENTS.md`
- `GOVERNANCE.md`
- `ENGINEERING_METHOD.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `supabase/migrations/202607059800_capability_grants_are_per_user_not_only_per_role.sql`

## Required Reading

- `reports/history/session-2026-09-09-slice11-closure.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md` — the `users` row
- `reports/master/MASTER_GAP_REGISTER.md` — SEC-1, IDENT-1, IDENT-2, ADMIN-1, AUTH-2
- `supabase/migrations/202607055100_role_change_audit_and_cursor_authority.sql` — `app.emit_role_change`, the precedent
- `supabase/tests/51_role_change_audit_test.sql` — the precedent's acceptance shape
- `supabase/tests/75_human_identity_family_test.sql` — IDENT-1 and the self-claim contract
- `supabase/migrations/202607053000_event_write_path_integrity.sql` — `app.record_event`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `ENGINEERING_METHOD.md §4` — the DATABASE protocol

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

## Implementation Steps

1. **Check:** `_ORVION_CANONICAL/27_event_catalog.md` contains the heading `## user_deactivated`. If present, record Already Applied. Otherwise, in the `# Organization And User Events` section, immediately after the `## user_created` entry and before `## user_branch_transfer_started`, add three entries in this exact order, each in the file's existing two-line form (`## <code>` then a blank line then `Severity: <severity>`): `## user_deactivated` with `Severity: security`; `## user_reactivated` with `Severity: security`; `## user_identity_bound` with `Severity: security`. Change no existing entry.

2. **Check:** a file matching `supabase/migrations/20260917120000_*.sql` exists. If present, record Already Applied. Otherwise create `supabase/migrations/20260917120000_a_membership_change_costs_the_same_through_every_door.sql` containing exactly these five parts and nothing else:
   - (a) an `insert into public.catalog_values (tenant_id, catalog_type_code, code, label, sort_order, is_active, is_system)` registering the three codes from Step 1 with `tenant_id` null, `is_system` true, `is_active` true, labels `User Deactivated`, `User Reactivated`, `User Identity Bound`, and `sort_order` 166, 167, 168;
   - (b) `create or replace function app.guard_membership_authority() returns trigger language plpgsql security definer set search_path to ''`, which returns `new` unchanged when `(select auth.uid()) is null`; returns `new` unchanged when `tg_op = 'UPDATE' and old.auth_user_id is null and new.auth_user_id = (select auth.uid())` and each of `tenant_id`, `email`, `is_active` and `is_platform_user` is `not distinct from` its `old` value; and otherwise `perform app.authorize('MANAGE_USERS')` before returning `new`;
   - (c) `create or replace function app.emit_membership_change() returns trigger language plpgsql security definer set search_path to ''`, which on `INSERT` calls `app.record_event(new.tenant_id, 'user_created', 'user', new.id, null, null, 'active', null, jsonb_build_object('email', new.email, 'has_auth_link', new.auth_user_id is not null), 'info')`; and on `UPDATE` emits `user_reactivated`/`user_deactivated` at severity `security` when `new.is_active is distinct from old.is_active`, and `user_identity_bound` at severity `security` with `previous_state`/`new_state` carrying the old and new `auth_user_id` as text when `new.auth_user_id is distinct from old.auth_user_id`; every `record_event` call passes `null` for `p_actor_user_id`;
   - (d) `revoke execute on function app.guard_membership_authority() from public;` and `revoke execute on function app.emit_membership_change() from public;`, then `create trigger users_guard_membership_authority before insert or update on public.users for each row execute function app.guard_membership_authority();` and `create trigger users_emit_membership_change after insert or update on public.users for each row execute function app.emit_membership_change();`;
   - (e) `create or replace function app.create_tenant_user(p_full_name text, p_email text, p_phone text default null, p_auth_user_id uuid default null) returns uuid language plpgsql set search_path to ''` identical to its current body except that the `select id into v_actor ...` statement, the `v_actor` declaration and the `perform app.record_event(...)` call are removed, leaving the tenant check, the `app.authorize('MANAGE_USERS')` call, the insert and the return.
   The migration must not add `app.guard_write_capability` to `public.users`, must not alter `users_enforce_identity_binding`, must not alter any RLS policy, and must not include `DELETE` in either trigger.

3. **Check:** `supabase/tests/118_membership_authority_and_audit_test.sql` exists. If present, record Already Applied. Otherwise create it as a pgTAP file following the `begin; select plan(N); … select finish(); rollback;` shape used by `supabase/tests/51_role_change_audit_test.sql`, asserting at minimum: the platform session-less INSERT is permitted and still emits `user_created` with `actor_user_id` null and `has_auth_link` recorded for both a linked and an unlinked membership; `app.activate_membership()` still succeeds for a confirmed claimant whose role is **`employee`** and separately for one whose role is `ceo`, and emits exactly one `user_identity_bound` each; `app.create_tenant_user` and the equivalent direct INSERT are BOTH refused with SQLSTATE `42501` at `aal1` and BOTH permitted at `aal2`, with the `aal2` RPC call emitting exactly one `user_created`; direct deactivation is refused at `aal1`, permitted at `aal2`, and emits exactly one `user_deactivated`, with reactivation emitting exactly one `user_reactivated`; an administrator may deactivate their own membership at `aal2`; identity re-binding is refused at `aal1`, permitted at `aal2`, emits exactly one `user_identity_bound`, and a mismatched email is still refused with SQLSTATE `23514` by `users_enforce_identity_binding`; an UPDATE that changes only `full_name` emits nothing; a non-`MANAGE_USERS` employee cannot insert or update a membership; a tenant may neither update nor insert into another tenant nor relocate a row between tenants; and a mutation control that drops `users_guard_membership_authority` inside a savepoint, proves the `aal1` direct INSERT then SUCCEEDS, rolls back, and proves it is refused again.

4. **Check:** `supabase/tests/10_grant_model_test.sql` contains `'users'` inside the `MEAS-2` `set_eq` expected array. If present, record Already Applied. Otherwise add `'users'` to that array (keeping the array's existing alphabetical ordering) and extend the assertion's description and the comment block immediately above it to state that `users` joined the bespoke-guard population under SPEC-193, that its guard charges `app.authorize` on every path, and that its two exemptions are session-less platform writes and the `activate_membership` self-claim. Change no other assertion in the file.

5. **Check:** `supabase/tests/35_subscription_write_gate_test.sql` contains the string `set_config('request.jwt.claims', null, true)` on a line preceding the `suspended: identity administration still works` assertion. If present, record Already Applied. Otherwise insert `select set_config('request.jwt.claims', null, true);` immediately before that `lives_ok` call and extend its description to state that the path being proved is the session-less platform write `provision_tenant` uses, not an administrator's session. Change no other assertion in the file.

6. **Check:** `supabase/tests/75_human_identity_family_test.sql` contains the string `SPEC-193` in assertion 11's description. If present, record Already Applied. Otherwise amend assertion 11's description only — leaving its SQL and its expected SQLSTATE `42501` unchanged — to record that since SPEC-193 the refusal is delivered by `users_guard_membership_authority` before RLS's `WITH CHECK` is reached, and that the RPC remains the only reachable claim path. Change no other assertion in the file.

7. **Check:** `reports/master/MASTER_GAP_REGISTER.md` contains a row whose first cell is `USR-1`. If present, record Already Applied. Otherwise add rows `USR-1` and `USR-2` in the file's existing table format marked resolved by this migration; update the existing `IDENT-2` row to resolved, stating it was closed by the same emitter rather than separately; and add one OPEN row recording the measured, deliberately unrepaired step-up gap on `user_permission_grants` and `user_branch_assignments` as separate surfaces.

8. **Check:** `reports/master/MASTER_SURFACE_DISPOSITION.md`'s `users` row reads `NOT-RECORDED`. If it does not, record Already Applied. Otherwise change that row's disposition to `AUDITED` with `ADVERSARIAL` evidence pointing at `supabase/tests/118_membership_authority_and_audit_test.sql`, and update the Coverage summary counts and its `ADVERSARIAL` sentence so they are derived from the rows (Check 22).

9. **Check:** `reports/history/session-2026-09-17-batch6-slice12-users.md` exists. If present, record Already Applied. Otherwise create it in the `HANDOFF / DISCOVERED / VERIFIED / FIXED / NOT FIXED / BLOCKED / GOVERNANCE / ENVIRONMENT / CURRENT STATE / NEXT STEP` shape used by `reports/history/session-2026-09-09-slice11-closure.md`, and add a new `> **Latest session report:**` pointer line at the top of `reports/README.md`, demoting the current pointer to a `> Previously:` line without altering any existing pointer text. The report must additionally carry a section headed `MIGRATION CI COMPARISON` which records: that this is the first Batch-6 database slice and therefore the slice `changes/SPEC-173-certified-evidence-names-its-context.md` named as the one that compares Migration CI against acceptance by evidence; the step-for-step correspondence derived by reading `.github/workflows/migration-ci.yml` and `.github/workflows/orvion-acceptance.yml` (both run `supabase db reset`, `supabase test db`, and the `scripts/verify_database.sql` smoke); the toolchain authority each one resolves its Supabase CLI from; and a `RESULT:` line left to be completed, after the candidate is pushed, with the Migration CI run identified by the exact candidate SHA, its `db reset` / pgTAP / smoke outcomes, and whether they agree with the local DATABASE evidence and the acceptance run for the same repository bytes. Any disagreement is recorded there as a named finding and carried to `reports/master/MASTER_GAP_REGISTER.md`; it is never resolved by preferring one side. This step changes no workflow file.

10. **Check:** `_ORVION_CANONICAL/manifest.md`'s `Batch 6 surface coverage` line reads `13 of 77`. If it does, record Already Applied. Otherwise update that line to `13 of 77`, and update `Last Completed` and `Next capability` together per `CR_LIFECYCLE.md §9` so that SPEC-193 becomes `Last Completed` and `Next capability` names Batch 6 Slice 13 ranked by `scripts/batch6_select_target.ps1`. Additionally set that file's `Narrative:` field to `session-2026-09-17-batch6-slice12-users.md` so it names the same report `reports/README.md`'s newest `Latest session report:` pointer names — Check 10 compares the two by value and rejects a mismatch as `STALE POINTER`.

11. **Check:** `ai-map.json`'s `live_state` copies of `Last Completed`, `Active Change Request` and `Next capability` are equal by value to `_ORVION_CANONICAL/manifest.md`'s. If they already agree, record Already Applied. Otherwise regenerate `ai-map.json` with `pwsh -NoProfile -File scripts/generate-ai-map.ps1` and re-check. Run this regeneration after EVERY commit in this Change Request's lifecycle that changes the manifest, including the `Approve` and `Complete` transitions, because Check 7 compares those three fields by value and `AI-MAP STALE` otherwise blocks the very first transition. If the generator script does not exist under that exact path, stop and report rather than hand-editing `ai-map.json`.

## Acceptance Criteria

- [ ] `_ORVION_CANONICAL/27_event_catalog.md` defines `user_deactivated`, `user_reactivated` and `user_identity_bound`, each at `Severity: security`, inside `# Organization And User Events`.
- [ ] `supabase/migrations/20260917120000_a_membership_change_costs_the_same_through_every_door.sql` exists and registers those three codes in `public.catalog_values`.
- [ ] `public.users` carries exactly one `BEFORE INSERT OR UPDATE` trigger executing `app.guard_membership_authority` and exactly one `AFTER INSERT OR UPDATE` trigger executing `app.emit_membership_change`, and neither trigger names `DELETE`.
- [ ] `app.guard_membership_authority` calls `app.authorize`, and neither new function grants `EXECUTE` to `PUBLIC`.
- [ ] `app.create_tenant_user` no longer contains a `record_event` call, and `app.emit_membership_change` is the only producer of `user_created`.
- [ ] `users_enforce_identity_binding` and all four RLS policies on `public.users` are byte-identical to their pre-change definitions, and `public.users` carries no `guard_write_capability` trigger.
- [ ] `supabase/tests/118_membership_authority_and_audit_test.sql` exists and includes an `activate_membership` regression assertion whose claimant holds the `employee` role, and a mutation control that drops `users_guard_membership_authority` inside a savepoint and proves the defect returns.
- [ ] `supabase/tests/10_grant_model_test.sql`'s `MEAS-2` expected array contains `users` and its description states why.
- [ ] `supabase/tests/35_subscription_write_gate_test.sql` clears `request.jwt.claims` before the `identity administration still works` assertion.
- [ ] `supabase/tests/75_human_identity_family_test.sql` assertion 11 records that the refusal now comes from `users_guard_membership_authority`, with its SQL and expected SQLSTATE unchanged.
- [ ] `reports/master/MASTER_GAP_REGISTER.md` carries `USR-1` and `USR-2` as resolved, `IDENT-2` as resolved by the same emitter, and one OPEN row naming `user_permission_grants` and `user_branch_assignments` as separate unrepaired surfaces.
- [ ] `reports/master/MASTER_SURFACE_DISPOSITION.md` records `users` as `AUDITED` / `ADVERSARIAL` and its Coverage summary agrees with its rows.
- [ ] `reports/history/session-2026-09-17-batch6-slice12-users.md` exists and `reports/README.md`'s newest pointer names it.
- [ ] That report carries a `MIGRATION CI COMPARISON` section naming the SPEC-173 obligation, the step-for-step correspondence derived from `.github/workflows/migration-ci.yml` and `.github/workflows/orvion-acceptance.yml`, each one's Supabase CLI authority, and a `RESULT:` line awaiting the candidate-SHA outcome; and no workflow file was modified.
- [ ] `_ORVION_CANONICAL/manifest.md` records Batch 6 coverage as `13 of 77` and names SPEC-193 as `Last Completed`.
- [ ] `_ORVION_CANONICAL/manifest.md`'s `Narrative:` field and `reports/README.md`'s newest `Latest session report:` pointer name the same file.
- [ ] `ai-map.json`'s live_state copies of `Last Completed`, `Active Change Request` and `Next capability` match `_ORVION_CANONICAL/manifest.md` by value.

## Execution Log

[Appended by the executing agent after each run against this Change Request, before
IMPLEMENT is considered complete, per synchronization as defined in `CR_LIFECYCLE.md` §8
— this file is always implicitly in scope for this section.
Append-only — never edit or delete a prior entry, including a Blocked or Failed one.
Leave this section's bracketed instructions in place in an unused template; remove them
only in a CR that has at least one real entry.]

## Verification Notes

### 2026-09-17 — Claude Opus 5 (reviewing agent)

Verdict: Needs Corrective Change Request

Findings — execution BEGAN in the working tree and could not be committed. No commit of any implementation byte was ever made under this contract, and nothing was deployed to Primary.

- **What was applied in the working tree and measured:** the three `security` event codes; the migration creating `users_guard_membership_authority` (BEFORE INSERT+UPDATE) and `users_emit_membership_change` (AFTER INSERT+UPDATE), neither naming DELETE, with `users_enforce_identity_binding` untouched; `create_tenant_user` losing its own `record_event`; and the new behavioural test. A clean `db reset` applied **219 migrations**, and the new test passed **29 of 29**, including the mandatory employee-claimant self-claim regression and a drop/restore mutation control.
- **BLOCKER 1 — a fixture outside frozen Write Scope.** `supabase/tests/31_access_revocation_test.sql` fails. At lines 74–75 it runs `reset role;` then a bare `update public.users set is_active = false` while `request.jwt.claims` is still set at line 65 to an `employee` identity. The new guard derives the caller from `auth.uid()` rather than from the SQL role, so that statement is judged as that employee's session and is correctly refused `permission denied: MANAGE_USERS`. It is the same stale-claim fixture shape already corrected in-scope in `35_subscription_write_gate_test.sql` and inside the new test, and the repair is one line — but that file is not in this contract's Write Scope, and `CR_LIFECYCLE.md §11` forbids widening approved Write Scope to absorb a discovery. Measured precisely: **118 files / 1936 assertions with exactly this one file failing**; no production behaviour is implicated and no guard was weakened to avoid it.
- **BLOCKER 2 — the control plane will not accept an undeployed migration.** The new migration and test made the manifest's `Live state:` figures stale, and the pre-commit Gate refused the commit with `MIGRATION STATE DRIFT` (manifest 218 vs repository 219; latest `20260909180403` vs `20260917120000`; ledger `70ba44e1…` vs `7f5b1e25…`) and `SUITE FIGURE DRIFT` (117 files vs 118; 1915 assertions vs 1944). That same sentence also asserts **proven Primary parity at the prior migration set**, and `scripts/check_primary_ledger.ps1` requires the recorded Primary ledger and the repository migration set to agree — so the figures cannot simply be incremented. Doing so would have published a parity claim that was never earned. Primary was read and remains at `20260909180403` with no `20260917120000`; nothing was deployed.
- **Therefore this contract cannot honestly reach completion as scoped.** Both blockers are dependency-closure failures of its Write Scope and Implementation Steps, not defects in the engineering design, which was revalidated against the live database before execution began.
- **State on cancellation:** the working tree was restored to this contract's Approved commit and the local database was reset to repository truth (218 migrations, `public.users` back to two triggers, no new event codes). An external forensic snapshot of the blocked implementation was preserved outside the repository as evidence only; it grants no write authority.

Recommendation to human: Approve corrective Change Request (successor), and Set Status to Cancelled on this one.

### 2026-09-17 — owner-authorized cancellation

Cancelled by explicit human command on the evidence above. The engineering objective, the revalidated USR-1 / USR-2 / IDENT-2 findings and the BEFORE+AFTER architecture are retained for a corrective successor allocated through the normal lifecycle; no successor identity is named here, because naming one before it is legally allocated is what retires an identifier.

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

**Why this is two triggers and not one, measured rather than argued.** `app.emit_role_change` is a single AFTER trigger that both charges the step-up and records the fact, and copying it was the obvious move. It was tested and rejected: with the check inside an AFTER trigger, an administrator deactivating their own membership is refused `permission denied: MANAGE_USERS`, because `public.users.is_active` is an input to `app.current_user_id()` and therefore to `app.has_permission`, so the check is evaluated against a world the statement has already changed. `user_role_assignments` has no such self-reference through `users.is_active`, which is the property that does not transfer. Authority is a precondition and runs BEFORE; the record is a fact and runs AFTER.

**Why the self-claim carve-out is not a caller-specific hack.** It states `activate_membership()`'s existing contract as a row condition: a membership that named nobody (`old.auth_user_id is null`) is bound to the caller's own identity (`new.auth_user_id = auth.uid()`) and nothing else about the row moves. It is measured non-forgeable: an administrator at `aal1` who tries to claim an unclaimed executive membership is refused `23514` by `users_enforce_identity_binding` (the row's email does not match their identity), and if they also rewrite the email to their own, the carve-out no longer applies and they are refused `42501` for the missing step-up. The claim path's contract is IDENT-1's verified-email/not-banned/not-deleted checks, not MFA, and this Change Request does not change it.

**IDENT-2 is closed by consequence, and that is stated rather than hidden (`AGENTS.md §5b`).** The emitter observes `auth_user_id`, and the claim moves `auth_user_id`; excluding the claim would have left exactly the gap USR-1 is about. Outcome 1 of the shared-mechanism question: the smallest coherent trigger audits the claim too.

**DELETE is deliberately excluded.** `authenticated` holds no `DELETE` on `public.users` (measured: only `postgres` and `service_role`), and `public.events` carries `FOREIGN KEY (tenant_id, actor_user_id) REFERENCES users(tenant_id, id) ON DELETE RESTRICT`. There is no reachable tenant-user delete door and no measured defect on one, so DELETE has not earned inclusion merely because the sibling trigger names it.

**The sibling surfaces stay separate.** `public.user_permission_grants` and `public.user_branch_assignments` were measured during this slice and neither charges the step-up on direct DML: an owner at `aal1` was able to grant themselves `APPROVE_FINANCE` directly. That is a real finding on a different surface, and `AGENTS.md §5b` requires each affected execution path to be classified separately rather than repaired by one generic widening. It is recorded as an OPEN row by Step 7 and is deliberately not repaired here; their defining migrations are named in Out of Scope so the boundary is mechanical rather than a promise.

**Migration CI is OBSERVED here, not changed (POST_PUSH expectation, recorded per `CR_LIFECYCLE.md §8`).** `changes/SPEC-173-certified-evidence-names-its-context.md` left Migration CI *"OBSERVE ONLY until the first real Batch-6 database slice can compare it against acceptance by evidence"*. This is that slice: it writes `supabase/migrations/**` and `supabase/tests/**`, which are two of Migration CI's own `push:` path filters, so `-Certify` will derive it into the expected workflow set automatically and a silently-missing run is already `PENDING`/`FAILED` rather than ignored. What `-Certify` does NOT do is compare the two runs' *content*, which is what SPEC-173 asked for. After the candidate is pushed, the obligation is: locate the Migration CI run for the **exact candidate SHA**; read its `supabase db reset`, `supabase test db` and `verify_database.sql` smoke results; compare each against the local DATABASE/Finish evidence and against the `orvion-acceptance` run for the same bytes; and record the outcome on the `RESULT:` line Step 9 creates. A disagreement is a finding carried to the register — never resolved by deciding which side to believe. One specific hypothesis to test rather than assume: `migration-ci.yml` resolves its CLI through `supabase/setup-cli@v3` pinned to **2.109.1**, while `orvion-acceptance` and local Finish resolve it from the lockfile (**2.109.0** installed, `^2.109.0` declared) — acceptance's own comment warns that a second `uses:` pin *"would create a second version authority that can silently disagree with the one developers actually run locally"*. Observing that divergence is not the same as reproducing a defect from it, so `.github/workflows/migration-ci.yml` is deliberately absent from Write Scope and is not edited by this Change Request. If the comparison reproduces a concrete disagreement, it earns its own Change Request.

**Vocabulary is three codes, not four.** A separate `user_identity_claimed` was considered and rejected: `previous_state` already distinguishes a first bind (null) from a re-point, so a fourth code would carry no fact the event does not already carry.


**On this contract's identity.** The engineering Draft below was prepared under the intended identity `SPEC-190`. It was never published as a tracked contract, and before it could be, `SPEC-190` was named in tracked text by `SPEC-191` and `SPEC-192` — both since promoted to `main`. Under `CR_LIFECYCLE.md §4` any tracked textual occurrence reserves an identifier, deliberately and unrepairably, so `190` became unallocatable and the Gate refused it as `SPEC_ID_ALREADY_USED`. The work was therefore allocated the next legal free identity before Approval. `SPEC-190` is a **retired/reserved identifier**, not a cancelled predecessor: no `SPEC-190` contract ever existed on `main`, nothing supersedes anything, and the historical `SPEC-190` references inside `SPEC-191` and `SPEC-192` are left exactly as published, because they are the evidence for why the identifier is retired. This is the same rule that retired `SPEC-187` when `SPEC-186`'s cancellation named its intended successor.