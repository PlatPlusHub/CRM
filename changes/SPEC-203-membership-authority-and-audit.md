# Change Request — SPEC-203

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Give `public.users` a path-independent membership boundary: every membership creation, activation change and identity re-binding costs the same step-up and reaches the audit spine through the table door as it does through `app.create_tenant_user`, while the `app.activate_membership()` self-claim and session-less platform provisioning keep working exactly as they do today.

## Business Reason

`public.users` is the row that decides who exists in a tenant and whether they can act. Batch 6 Slice 12 selected it by measurement (`scripts/batch6_select_target.ps1`: Exposure **15**, the highest surface still `NOT-RECORDED`), and two defects were reproduced against the clean local baseline at `c28c526`. Both were **re-confirmed live against `9380bce`** before this contract was written, and the product surface is provably unchanged in between — `git diff c28c526..9380bce` touches no path under `supabase/`, `scripts/verify_database.sql`, `_ORVION_CANONICAL/27_event_catalog.md` or either Master record, and the local stack still reads 218 migrations, catalog `71/618`, and exactly two triggers on `public.users`:

- **USR-1 — the audit spine does not see this table.** One actor, at one moment, created a membership, deactivated a colleague and unbound a third human from their membership through direct DML. Events for the tenant stayed at **3 → 3**: nothing was recorded. The same `user_created` fact through `app.create_tenant_user` moved it **3 → 4**, because that function calls `app.record_event` inside itself — the RPC-only-producer shape `202607055100` already removed from `assign_user_role`. `users` is the only member of the canon-34 identity-and-access family with no emitter at all.
- **USR-2 — the same administrative act costs a step-up through the RPC and nothing through the table.** Measured on one actor holding `MANAGE_USERS` with `app.mfa_satisfied()` false: `app.create_tenant_user` raised `42501 multi-factor authentication required for this role`, and in the same transaction the equivalent direct `INSERT`, a direct deactivation and a direct identity re-point all succeeded. `app.authorize` is permission **and** MFA; the RLS policy calls `app.has_permission`, which is permission only.

Closing these also closes **IDENT-2** (the membership claim emits no event), because the claim moves the same `auth_user_id` column the new emitter observes.

## Risks

- **Breaking legitimate onboarding is the main risk.** A guard that charged `app.authorize('MANAGE_USERS')` on every session-backed write would make `app.activate_membership()` impossible for an ordinary employee, who holds no `MANAGE_USERS` (measured: an employee's direct write is refused by RLS). The self-claim carve-out and a mandatory **employee-claimant** regression assertion both exist for this, and the carve-out was attacked before being accepted.
- **The carve-out reads `new` to decide authority**, which is the shape of BOOK-5 / LEAD-1 / PAX-3. It was attacked rather than argued: an administrator at `aal1` pointing an unclaimed executive membership at their own identity is refused `23514` by `users_enforce_identity_binding`, which verifies against `auth.users` — state the attacker does not control — and if they also rewrite the email, the carve-out no longer applies and they are refused `42501`. The carve-out is admissible only because an independent control that does **not** read the attacker's image is what actually decides it.
- **Trigger timing is load-bearing.** Authority is a precondition and must run BEFORE; the record is a fact and must run AFTER. `public.users.is_active` is an input to `app.current_user_id()` and therefore to permission resolution, so an authority check placed AFTER would refuse an administrator deactivating their own membership.
- **Blast radius is real and was enumerated by measurement, not inherited.** A prototype was applied to the local stack only and the full suite run: **exactly three** existing files move — `10_grant_model_test.sql` (MEAS-2 gains `users`), `31_access_revocation_test.sql` and `35_subscription_write_gate_test.sql` (both stale-JWT fixture defects). All three are in Write Scope. The prototype was reverted with `npx supabase db reset` and the baseline re-proved before this contract was written.
- Adding three event codes widens vocabulary. Mitigated by keeping it to the smallest set that can truthfully name the measured transitions.
- Not repairing leaves an administrator able to transfer a role-bearing membership to another human with no step-up and no trace.

## Supersedes / Depends On

None. `SPEC-193`, `SPEC-194`, `SPEC-195` and `SPEC-197` are terminal `Cancelled` contracts covering this same slice; this Change Request does not supersede, extend, amend or edit any of them, and requires no status change on any file. None of them was cancelled because a finding was falsified.

`SPEC-197` in particular carried this contract's engineering and reached `In Progress` with a non-vacuous automatic `APPROVAL_EVIDENCE: PASS`. It was cancelled for a **control-plane publication** reason that has since been repaired and published: its range was refused `FROZEN_AUTHORITY_MUTATED` because the endpoint comparison treated a `Draft` at the range base as frozen authority (`CTRL-2A`, repaired by `SPEC-201` at `f0b5af0`), the repair lay in a file its own frozen Out of Scope forbade, and no corrective contract could be authored while it governed. **USR-1 and USR-2 were never disproven**, and both were re-confirmed live against `9380bce` before this contract was written.

## Write Scope

- `changes/SPEC-203-membership-authority-and-audit.md`
- `supabase/migrations/20260920120000_membership_authority_and_audit.sql`
- `supabase/tests/118_membership_authority_and_audit_test.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/31_access_revocation_test.sql`
- `supabase/tests/35_subscription_write_gate_test.sql`
- `scripts/verify_database.sql`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `reports/evidence/primary-ledger-evidence.json`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-193-a-membership-change-costs-the-same-through-every-door.md`
- `changes/SPEC-194-a-membership-change-costs-the-same-through-every-door.md`
- `changes/SPEC-195-a-membership-change-costs-the-same-through-every-door.md`
- `changes/SPEC-197-membership-authority-and-audit.md`
- `changes/SPEC-200-draft-baseline-and-approval-replay.md`
- `changes/SPEC-201-draft-baseline-and-approval-replay.md`
- `changes/SPEC-202-origination-must-begin-as-draft.md`
- `supabase/tests/75_human_identity_family_test.sql`
- `supabase/migrations/202607055100_role_change_audit_and_cursor_authority.sql`
- `supabase/migrations/202607057800_an_unverified_email_is_not_proof_of_identity.sql`
- `supabase/migrations/202607058000_a_membership_may_not_claim_a_different_human.sql`
- `supabase/migrations/202607059800_capability_grants_are_per_user_not_only_per_role.sql`
- `reports/history/session-2026-09-09-ten-decision-closure.md`
- `reports/README.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `scripts/generate-ai-map.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/batch6_select_target.ps1`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/orvion-acceptance.yml`
- `AGENTS.md`
- `GOVERNANCE.md`
- `ENGINEERING_METHOD.md`
- `CR_LIFECYCLE.md`

## Required Reading

- `reports/master/MASTER_SURFACE_DISPOSITION.md` — the `users` row and the Coverage section
- `reports/master/MASTER_GAP_REGISTER.md` — IDENT-1, IDENT-2, SEC-1, ADMIN-1, AUTH-2
- `supabase/migrations/202607055100_role_change_audit_and_cursor_authority.sql` — `app.emit_role_change`, the precedent this contract reuses for both trigger shape and actor resolution
- `supabase/tests/51_role_change_audit_test.sql` — that precedent's acceptance shape
- `supabase/tests/10_grant_model_test.sql` — assertion 9 (MEAS-2) and its "must never rise" rule
- `supabase/migrations/202607053000_event_write_path_integrity.sql` — `app.record_event`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `scripts/verify_database.sql` — `CHECK 6a`/`CHECK 6b` and the `ALL CHECKS PASSED` notice
- `scripts/check_primary_ledger.ps1` — what the recorded Primary evidence must satisfy
- `reports/evidence/primary-ledger-evidence.json` — the current recorded Primary reading and its `read_query`
- `ENGINEERING_METHOD.md §4` — the DATABASE protocol, and that Primary for this repository is only `vrvtsxexkiiiivlkdxzp`
- `reports/master/MASTER_INTEGRATION_CATALOG.md §0` — deployment topology; Secondary `brplkqmbzffpxqgkkdzo` is never a CRM target

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

### Derived Applicability

| Predicate | Repository-derived fact | Result |
| --- | --- | --- |
| Consumer Closure | The migration moves `catalog_values` 618 → 621 and the migration set 218 → 219; `git grep` shows both counts are pinned by tracked executable invariants (`scripts/verify_database.sql`, `reports/evidence/primary-ledger-evidence.json`) and republished by `_ORVION_CANONICAL/manifest.md` | APPLICABLE |
| Execution-Boundary Satisfiability | The contract contains an irreversible action — deploying a migration to Primary `vrvtsxexkiiiivlkdxzp` — and mandatory Gates run on either side of it | APPLICABLE |
| Permanent-Control Admission | Two new permanent database controls are proposed: `app.guard_membership_authority` (BEFORE) and `app.emit_membership_change` (AFTER) | APPLICABLE |
| SPEC Allocation | This contract allocates a new repository engineering identity | APPLICABLE |

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| `catalog_values` 618 → 621 | `scripts/verify_database.sql` — head comment, `CHECK 6b`, `ALL CHECKS PASSED` notice | WRITE | Measured: the literal `618` appears in exactly those three places in that file; `CHECK 6a`'s `catalog_types` pin of 71 does not move, because the three rows are seeded under an existing catalog type |
| `catalog_values` 618 → 621 | `_ORVION_CANONICAL/manifest.md` `Live state:` (`71/618 catalog`) | WRITE | Remeasured post-deployment by Step 12, never incremented on paper |
| migration set 218 → 219, latest → `20260920120000`, ledger fingerprint | `reports/evidence/primary-ledger-evidence.json`; `_ORVION_CANONICAL/manifest.md` `Live state:` | WRITE | Both rewritten from a post-deployment Primary read (GUARD-1), never from a repository list |
| migration set 218 → 219 | `scripts/check_primary_ledger.ps1`, `scripts/check_database_parity.ps1`, `scripts/check_repository_consistency.ps1` | VERIFY | Measured: none of the three hard-codes `618`, `621`, `1915`, `218` or any migration identity — each derives them. They are correctly detecting state and must not be edited to admit a change |
| `public.users` gains a bespoke capability trigger | `supabase/tests/10_grant_model_test.sql` assertion 9 (MEAS-2) | WRITE | Measured by running the suite against a local prototype: the assertion fails with `Extra records: (users)`. The population "must never rise", so the step must state why this eleventh entry is admissible |
| `public.users` writes now charge `app.authorize` | `supabase/tests/31_access_revocation_test.sql` | WRITE | Measured: the file aborts (exit 3) after 2 of 10 assertions. `reset role` clears the SQL role but leaves `request.jwt.claims`, so `auth.uid()` still resolves to the employee. FIXTURE repair only |
| `public.users` writes now charge `app.authorize` | `supabase/tests/35_subscription_write_gate_test.sql` assertion 19 | WRITE | Measured: dies `42501` — the assertion names the session-less `provision_tenant` path but leaves a JWT claim set. FIXTURE repair only |
| `public.users` writes now charge `app.authorize` | `supabase/tests/75_human_identity_family_test.sql` | UNAFFECTED | Measured: the file passes unchanged against the prototype. It is named in Out of Scope so the boundary is mechanical |
| event vocabulary +3 codes | `_ORVION_CANONICAL/27_event_catalog.md` | WRITE | Canon 27 is the sole owner of the event vocabulary |
| event vocabulary +3 codes | `_ORVION_CANONICAL/25_catalog_registry.md` | UNAFFECTED | Measured: it carries no `## event_type` section; adding one would create a second owner |
| `app.create_tenant_user` loses its `record_event` call | `reports/master/MASTER_API_CONTRACT.md` (GENERATED) | UNAFFECTED | Proven cell by cell against the live row `\| create_tenant_user \| … \| uuid \| invoker \| MANAGE_USERS \| users \| - \| 1 \| yes \|`: `inserts` names `users`, not `events`; `updates` `-`; `raises` 1; signature and `invoker` unchanged. No cell moves |
| `users` → `AUDITED-OPEN` / `ADVERSARIAL`, coverage 12 → 13 of 77 | `reports/master/MASTER_SURFACE_DISPOSITION.md` rows and derived counts; `_ORVION_CANONICAL/manifest.md` | WRITE | Check 22 recomputes the Coverage totals from the rows; Check 24 requires the cited test file to declare `-- ATTACK-CLASSES:` and carry a negative assertion |
| findings USR-1 / USR-2 / USR-3 / USR-4 / IDENT-2 | `reports/master/MASTER_GAP_REGISTER.md` | WRITE | Check 22 rejects a disposition row citing a finding id with no register row |
| migration set, suite population, catalog counts as they stood on 2026-09-09 | `reports/history/session-2026-09-09-ten-decision-closure.md` | UNAFFECTED | Found by the sweep and deliberately not written: it is a dated historical record of what was true then, not live state. Editing it would falsify history and would trip Check 21 |
| Check 5's 7000-character manifest budget | `_ORVION_CANONICAL/manifest.md` current-state readers, Check 5, the cold-boot sequence | UNAFFECTED | `SPEC-197` had to authorize trimming an unrelated entry because the file stood at 6971. Re-measured live against `9380bce`: **6854**, and this contract's `Active Change Request` pointer brings it to **6900**. No trim of any unrelated entry is authorized and none is needed; Step 12's ordinary bookkeeping re-measures rather than assumes and is written to stay inside the budget |
| The `Session` column's definition in the disposition legend | Check 22 (`check_repository_consistency.ps1`), `scripts/batch6_select_target.ps1`, `scripts/test_status_contradiction_guard.ps1` | VERIFY | Measured, not assumed: Check 22 resolves the cell against a repository-wide basename index built by `Get-ChildItem -Recurse`, so a terminal Change Request already resolves exactly as a session report does; the selector's row regex captures only the Surface and Disposition cells; the status-contradiction guard mutates only the Coverage totals. No consumer requires the cell to point inside `reports/history/` |
| `USR-4` recorded as DEFER WITH TRIGGER rather than an owner decision | `reports/master/MASTER_GAP_REGISTER.md`'s own disposition vocabulary, and Check 25 (GOV-16), which requires every register entry awaiting a DECIDER to be named on the manifest's boot line | VERIFY | Classifying `USR-4` as an owner decision would oblige a manifest boot-line entry for a decision nobody is owed, because nothing reads the column and no business question has been reached. DEFER WITH TRIGGER carries no such obligation and is what the evidence supports |
| This contract's SPEC identity prose restated as a historical allocation | no mechanical consumer | UNAFFECTED | Identity legality is derived at run time by `Validate-SpecAllocation` from the committed allocation and the Reservation Rule; the section is evidence for a human reader and is read by nothing. Correcting a stale present-tense claim removes a false current-state assertion without touching the fact it records |
| any | `.github/workflows/migration-ci.yml`, `.github/workflows/repository-consistency.yml` | UNAFFECTED | Their `push:` path filters already cover `supabase/migrations/**`, `supabase/tests/**` and `scripts/verify_database.sql`. They observe this change; they do not encode it |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 11 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Check 10 — manifest `Narrative:` equals `reports/README.md`'s newest session pointer | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 10 |
| `CHECK 6b` catalog pin equals the clean-reset database | BEFORE_IRREVERSIBLE_ACTION | Step 2 | Step 7 | Step 10 |
| Check 22 — disposition rows, Coverage totals and cited finding ids agree | BEFORE_IRREVERSIBLE_ACTION | Step 9 | Step 9 | Step 10 |
| Check 24 — `ADVERSARIAL` is earned by the cited file | BEFORE_IRREVERSIBLE_ACTION | Step 9 | Step 9 | Step 10 |
| Check 9 / Check 19 — manifest migration figures and the Primary ledger agree with the repository | AFTER_IRREVERSIBLE_ACTION | Step 2 | Step 12 | Step 13 |
| Check 15 — manifest declared assertion total equals the `plan(N)` sum | AFTER_IRREVERSIBLE_ACTION | Step 3 | Step 12 | Step 13 |
| Check 7 — `ai-map.json` live_state equals the manifest by value | AFTER_IRREVERSIBLE_ACTION | Step 12 | Step 13 | NONE |
| Check 5 — `_ORVION_CANONICAL/manifest.md` inside its 7000-character budget | BEFORE_COMPLETION | NONE | NONE | NONE |
| All profiles green with a fresh certification receipt | BEFORE_COMPLETION | NONE | NONE | NONE |

**MANIFEST-1 was measured again and does not recur.** `SPEC-197` had to authorize a manifest trim because the file stood at 6971 of Check 5's 7000-character budget and an `Active Change Request` pointer costs 46 more, so its Approve commit was structurally guaranteed to trip `MANIFEST BLOAT`. Re-measured against `9380bce`: the manifest is **6854** characters, and this contract's pointer brings it to **6900** — inside budget with headroom, so no trim is authorized and none is needed. `_ORVION_CANONICAL/manifest.md` remains in Write Scope for the ordinary completion bookkeeping, and Step 12 re-measures rather than assumes. The budget is never raised and Check 5 is never weakened.

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: `app.guard_write_capability` is the repository's unconditional generic guard, and a table carrying it needs no bespoke review. It cannot be used here: it decides a full bypass from `new.assigned_user_id` (the LEAD-1 defect), and `public.users` has no such column. `app.emit_role_change` is the correct precedent and is **reused in shape and in actor resolution** — BEFORE authority, AFTER record, actor from `app.current_user_id()` — but it is bound to `user_role_assignments` and cannot govern a different table. Putting `app.authorize` inside the RLS policy was rejected: policies are boolean predicates, `app.authorize` raises rather than returns, and a policy cannot record a fact. Revoking `INSERT`/`UPDATE` on `public.users` from `authenticated` was rejected as an architecture decision belonging to the owner, not to a slice: direct DML through PostgREST is a supported door by design across this repository.

Added Property: that the authority charged for a membership change is a property of the **table**, not of the door the caller chose, and that the change is recorded whichever door it came through.

Causal Negative: reproduced this session against unmodified `c28c526` — one actor holding `MANAGE_USERS` with `app.mfa_satisfied()` false was refused `42501` by `app.create_tenant_user` and, in the same transaction, successfully created a membership, deactivated a colleague and unbound a human by direct DML, with the tenant's event count unchanged at 3.

Positive Test Design: the session-less platform INSERT still succeeds and emits `user_created` with `actor_user_id` null; `app.activate_membership()` still succeeds for a confirmed claimant holding the **`employee`** role and emits exactly one `user_identity_bound` attributed to the claimant; an administrator at `aal2` may create, deactivate and re-point memberships, and may deactivate their own membership.

Negative Test Design: at `aal1`, both `app.create_tenant_user` and the equivalent direct INSERT are refused with SQLSTATE `42501`; direct deactivation and direct identity re-binding are refused `42501`; an employee holding no `MANAGE_USERS` is refused by RLS; a foreign tenant may neither insert into nor relocate a row across the tenant boundary; an administrator at `aal1` riding the self-claim carve-out against an unclaimed executive membership is refused `23514` by `users_enforce_identity_binding`, and is refused `42501` once they also move `email`, `is_active` or `is_platform_user`.

Non-Empty Population Obligation: the assertions that count emitted events must prove the matched population is non-empty — an event-count assertion that passes because it selected nothing is the failure mode this obligation exists for. Specifically: exactly one `user_created` for the `aal2` RPC call (the prototype measured **2** when `app.create_tenant_user` kept its own `record_event`, which is why Step 2(e) removing it is causally required and not cosmetic), exactly one `user_deactivated`, one `user_reactivated` and one `user_identity_bound` for their respective transitions, and zero events for an UPDATE that changes only `full_name`.

Mutation Obligation: each load-bearing predicate independently killed — (i) dropping `users_guard_membership_authority` inside a savepoint must make the `aal1` direct INSERT succeed, and it must be refused again after rollback; (ii) dropping `users_emit_membership_change` must make the `user_deactivated` assertion fail; (iii) removing the `auth.uid() is null` branch must break the session-less platform write; (iv) removing the self-claim carve-out must break the `employee` claimant's `activate_membership()`.

Post-Implementation Proof Obligation: `npx supabase test db` reports 0 failures and the number of assertions executed equals the sum of the literal `plan(N)` declarations across `supabase/tests` — no file plans more than it runs. That equality is itself evidence, because the measured baseline gap (declared 1915, executed 1907) was caused by `31_access_revocation_test.sql` aborting at assertion 2, which is one of the defects this contract repairs.

### SPEC Identity Allocation

Applicability: APPLICABLE

Derived mechanically, not chosen. At allocation the first-parent sequence cursor stands at **202** (`SPEC-202`, Complete at `9380bce`); the candidate is `cursor + 1` = **203**; `SPEC-203` is unreserved by all three reservation queries — absent from the current tree, from every added or renamed path in reachable history, and from the content pickaxe over that history — so no skip is required and the first free candidate is itself. `SPEC-199` remains permanently reserved and is not reclaimed. No repository numeric maximum, manual cursor, fixture allowlist or hard-coded expectation was used, and no future identifier is written into tracked text by this contract.

This contract is **originated as a `Draft`**, which `SPEC-202` now requires of every identity allocated after the activation boundary: a contract that first appeared as `Approved` would be refused `ORIGINATION_NOT_DRAFT`, so the human `Draft -> Approved` decision this contract awaits is the only way it can acquire authority.

## Implementation Steps

1. **Check:** `_ORVION_CANONICAL/27_event_catalog.md` contains the heading `## user_deactivated`. If present, record Already Applied. Otherwise, in the `# Organization And User Events` section, immediately after the `## user_created` entry and before `## user_branch_transfer_started`, add three entries in this exact order, each in the file's existing two-line form (`## <code>`, a blank line, then `Severity: <severity>`): `## user_deactivated` with `Severity: security`; `## user_reactivated` with `Severity: security`; `## user_identity_bound` with `Severity: security`. Change no existing entry.

2. **Check:** a file matching `supabase/migrations/20260920120000_*.sql` exists. If present, record Already Applied. Otherwise create `supabase/migrations/20260920120000_membership_authority_and_audit.sql` containing exactly these five parts and nothing else:
   - (a) an `insert into public.catalog_values (tenant_id, catalog_type_code, code, label, sort_order, is_active, is_system)` registering the three codes from Step 1 under `catalog_type_code` `event_type`, with `tenant_id` null, `is_system` true, `is_active` true, labels `User Deactivated`, `User Reactivated`, `User Identity Bound`, and `sort_order` **932, 933, 934**. These values are measured, not chosen by pattern: `event_type` currently holds 184 rows whose maximum `sort_order` is 931, and 166/167/168 — the values the cancelled `SPEC-195` froze for these same three codes — are already held by `refund_approved`, `refund_rejected` and `refund_cancelled`.
   - (b) `create or replace function app.guard_membership_authority() returns trigger language plpgsql security definer set search_path to ''`, which returns `new` unchanged when `(select auth.uid()) is null`; returns `new` unchanged when `tg_op = 'UPDATE' and old.auth_user_id is null and new.auth_user_id = (select auth.uid())` and each of `tenant_id`, `email`, `is_active` and `is_platform_user` is `not distinct from` its `old` value; and otherwise calls `perform app.authorize('MANAGE_USERS')` before returning `new`.
   - (c) `create or replace function app.emit_membership_change() returns trigger language plpgsql security definer set search_path to ''`, resolving `v_actor uuid := app.current_user_id()` once, then: on `INSERT` calling `app.record_event(new.tenant_id, 'user_created', 'user', new.id, v_actor, null, 'active', null, jsonb_build_object('email', new.email, 'has_auth_link', new.auth_user_id is not null), 'info')`; on `UPDATE` emitting `user_reactivated`/`user_deactivated` at severity `security` when `new.is_active is distinct from old.is_active`, and `user_identity_bound` at severity `security` with `previous_state`/`new_state` carrying the old and new `auth_user_id` as text when `new.auth_user_id is distinct from old.auth_user_id`. It returns `null`.
   - (d) `revoke execute on function app.guard_membership_authority() from public;` and `revoke execute on function app.emit_membership_change() from public;`, then `create trigger users_guard_membership_authority before insert or update on public.users for each row execute function app.guard_membership_authority();` and `create trigger users_emit_membership_change after insert or update on public.users for each row execute function app.emit_membership_change();`
   - (e) `create or replace function app.create_tenant_user(p_full_name text, p_email text, p_phone text default null, p_auth_user_id uuid default null) returns uuid language plpgsql set search_path to ''` identical to its current body except that the `v_actor` declaration, the `select id into v_actor …` statement and the `perform app.record_event(...)` call are removed, leaving the tenant check, the `app.authorize('MANAGE_USERS')` call, the insert and the return.
   The migration must not add `app.guard_write_capability` to `public.users`, must not alter `users_enforce_identity_binding`, must not alter any RLS policy, and must not include `DELETE` in either trigger.

3. **Check:** `supabase/tests/118_membership_authority_and_audit_test.sql` exists. If present, record Already Applied. Otherwise create it as a pgTAP file in the `begin; select plan(N); … select finish(); rollback;` shape used by `supabase/tests/51_role_change_audit_test.sql`, carrying an `-- ATTACK-CLASSES:` declaration drawn from the closed vocabulary in `MASTER_EXECUTION_PLAN.md` and at least one `throws_ok`, and asserting at minimum every item listed in this contract's `Positive Test Design`, `Negative Test Design`, `Non-Empty Population Obligation` and `Mutation Obligation`. It must additionally pin, as a stated property rather than an accident, that an administrator deactivating their **own** membership emits `user_deactivated` with `actor_user_id` null, because `app.current_user_id()` requires `is_active` and the AFTER trigger observes the post-image.

4. **Check:** `supabase/tests/10_grant_model_test.sql` contains `'users'` inside the `MEAS-2` `set_eq` expected array. If present, record Already Applied. Otherwise add `'users'` to that array, keeping the array's existing ordering, change the assertion's count wording from NINE to TEN, and extend the assertion description and the comment block immediately above it to state that `users` joined the bespoke-guard population under SPEC-203, that its guard charges `app.authorize` unconditionally on every path, and that its only two exemptions are the session-less platform write and the `activate_membership` self-claim, each of which is pinned by a named assertion in `118_membership_authority_and_audit_test.sql`. Change no other assertion in the file.

5. **Check:** `supabase/tests/35_subscription_write_gate_test.sql` contains `set_config('request.jwt.claims', null, true)` on a line preceding the `suspended: identity administration still works` assertion. If present, record Already Applied. Otherwise insert `select set_config('request.jwt.claims', null, true);` immediately before that `lives_ok` call and extend its description to state that the path being proved is the session-less platform write `provision_tenant` uses, not an administrator's session. Change no other assertion in the file.

6. **Check:** `supabase/tests/31_access_revocation_test.sql` contains the string `SPEC-203` in a comment immediately above its administrative deactivation. If present, record Already Applied. Otherwise insert `select set_config('request.jwt.claims', null, true);` immediately before the bare `update public.users set is_active = false where id = '32000000-0000-0000-0000-000000000011';` that follows its `reset role;`, carrying a comment headed `SPEC-203` recording that `reset role` clears the SQL role but not the JWT claim, that `users_guard_membership_authority` derives the caller from `auth.uid()` rather than from the SQL role, and that this is the same stale-claim fixture defect corrected in `35_subscription_write_gate_test.sql`. Change nothing else in the file: not its plan count, not any assertion's SQL, expected value or description, and not the claim it sets afterwards. This is a FIXTURE repair only; the file must still prove that a deactivated employee resolves to no tenant, no user, sees nothing and holds nothing.

7. **Check:** `scripts/verify_database.sql` contains the string `621 catalog_values`. If present, record Already Applied. Otherwise, AFTER a clean `npx supabase db reset` that includes this contract's migration, INDEPENDENTLY re-count `select count(*) from public.catalog_values` and `select count(*) from public.catalog_types` against that reset database, and only then update the file's pins from the measured values. The count is not incremented on paper: it is read, and the read must show exactly **621** — 618 plus this contract's three `event_type` rows and nothing else. Prove the difference is exactly those three codes by naming them. Update all three living places that state the pin: the baseline comment at the file's head, the `CHECK 6b` assertion itself, and the closing `ALL CHECKS PASSED` notice which embeds `71/618`. Extend that check's existing causal-history comment with one line recording this slice's `618 -> 621` step, in the voice the file already uses. **Do not weaken the assertion**: it stays an exact equality on a literal, never an inequality, a range or a tolerance. `CHECK 6a`'s `catalog_types` pin of **71** must be left untouched and the measurement must CONFIRM it is still 71 rather than assume it. Causally prove the repair in both directions: the pre-change file FAILS against the new clean-reset state with `CHECK 6b FAILED: expected 618 catalog_values, found 621`, and the updated file PASSES against that same state. Change no other check in the file. This step precedes the pre-deploy gate deliberately: that gate requires `ALL CHECKS PASSED`, which cannot hold while the pin still reads 618.

8. **Check:** `reports/master/MASTER_GAP_REGISTER.md` contains a row whose first cell is `USR-1`. If present, record Already Applied. Otherwise add, in the file's existing table format: `USR-1` and `USR-2` marked resolved by this migration; update the existing `IDENT-2` row to resolved, stating it was closed by the same emitter rather than separately; one OPEN row identified as `USR-3` recording the measured step-up gap on `public.user_permission_grants` and `public.user_branch_assignments` as separate surfaces, with the reproduction — a `ceo` at `aal1` self-granted `VIEW_ADVANCED_DASHBOARDS`, moving `app.has_permission` from false to true, and self-assigned an additional branch, while the same actor was refused `42501` on `public.user_role_assignments` — and noting that the permission-grant door does emit an event, so that gap is step-up only; and one OPEN row identified as `USR-4` recording that `public.users.is_platform_user` is settable by a tenant administrator and is read by no function, policy or tracked consumer in this repository, classified DEFER WITH TRIGGER whose exact trigger is the first time any policy, function or application path reads that column, and noting that this contract closes the `aal1` half by consequence because the guard charges on every column. Both new rows carry an **EMPTY Owner Decision column**, which is that file's own recorded convention for non-blocking engineering debt (`PAX-4`, `CUST-6`, `IDENT-2` and others). This is deterministic, not stylistic: Check 25 (GOV-16) surfaces every unsettled register entry whose Owner-Decision field names a decider, so giving either row a decider would oblige a matching entry on the manifest's open-decision line for a decision nobody is owed — neither finding has reached a business or compliance question.

9. **Check:** `reports/master/MASTER_SURFACE_DISPOSITION.md`'s `users` row reads `NOT-RECORDED`. If it does not, record Already Applied. Otherwise change that row to disposition `AUDITED-OPEN` with assurance `ADVERSARIAL`, its session cell citing `SPEC-203-membership-authority-and-audit`, its findings cell citing `USR-1, USR-2, USR-4`, and its next cell naming `USR-4` as DEFER WITH TRIGGER with its exact trigger — the first time any policy, function or application path reads `is_platform_user` — stated in the same words Step 8 writes into the register; and update the Coverage section's totals and its `ADVERSARIAL` sentence so every number is derived from the rows, which Check 22 recomputes. `AUDITED-OPEN` rather than `AUDITED` because a finding remains open on this surface; that is the only condition `AUDITED-OPEN` encodes, and it does **not** imply an owner decision is owed. No owner decision is claimed for `USR-4`: nothing currently reads the column, so no business or compliance question has been reached — only a deferral with a named trigger. Additionally, in that file's `## Coverage` legend, amend the one-line definition of the **Session** column so it names the immutable evidence artifact that owns the recorded audit evidence — normally a session report, and a terminal Change Request when the repository deliberately wrote none, as `SPEC-160` already did — leaving the rest of that line, the `Findings` and `Next` definitions, and every other row untouched.

10. **Check:** the working tree contains exactly one migration absent from the ledger recorded in `reports/evidence/primary-ledger-evidence.json`. Perform the pre-deploy readiness gate. Every item must hold and each must be recorded in the Execution Log with its measured result; the first that does not hold is a STOP, and nothing is deployed while it stands:
   - a clean `npx supabase db reset` completed;
   - pgTAP **Pass A** ran after that reset with 0 failures;
   - every `scripts/verify_*` suite named in Additional Verification ran with 0 failures;
   - pgTAP **Pass B** ran after those suites with 0 failures;
   - the number of assertions executed equals the sum of the literal `plan(N)` declarations across `supabase/tests`;
   - `scripts/verify_database.sql` completed with `ALL CHECKS PASSED`;
   - `supabase/tests/31_access_revocation_test.sql` passes AND still proves its own subject;
   - `supabase/tests/118_membership_authority_and_audit_test.sql` passes in full, including its employee-claimant self-claim regression and all four mutation controls;
   - `git status --porcelain` shows no path outside this contract's Write Scope;
   - `supabase/migrations/` contains exactly one migration absent from the recorded Primary ledger, and it is byte-identical to the file Step 2 created;
   - `pwsh -NoProfile -File scripts/check_repository_consistency.ps1` is run and its result recorded. It is EXPECTED to be non-green here. Exactly **three** failure classes are admissible, all of them the same bounded undeployed state seen from three angles, and each must be named and matched to that cause: `MIGRATION STATE DRIFT`; `SUITE FIGURE DRIFT`; and **RECOVER-1 / Check 19**, admissible only when the guard's `only in repository` set contains exactly one entry and that entry is `20260920120000_membership_authority_and_audit`, its `only on Primary` set is empty, and the evidence file is present, valid, complete, internally consistent and attributable to this history. **Any failure outside those three classes is a STOP**, explicitly including any `Check 10` result, any `PRIMARY HAS … MIGRATION(S) THE REPOSITORY DOES NOT` report, more than one repository-only migration, or any evidence-file attribution failure.

11. **Check:** `reports/evidence/primary-ledger-evidence.json`'s `ledger` array contains an entry beginning `20260920120000`. If present, record Already Applied. Otherwise perform the Primary synchronization, in this order and no other, stopping at the first step that does not hold:
   - (a) confirm the deployment target is project ref `vrvtsxexkiiiivlkdxzp` by reading it live through the `supabase-primary` connector, and confirm it is not Secondary `brplkqmbzffpxqgkkdzo`;
   - (b) read Primary's current migration ledger, before deploying anything, with the exact read recorded in the evidence file's `read_query` field;
   - (c) prove from that reading that `20260920120000` is ABSENT and that the pre-deployment ledger equals the currently recorded evidence — same `migration_count` and same `ledger_fingerprint`;
   - (d) re-confirm (a), (b) and (c) immediately before deploying, then apply ONLY `supabase/migrations/20260920120000_membership_authority_and_audit.sql` through the connector's migration-apply call, and nothing else;
   - (e) if the connector assigns its own migration version on apply, normalise that version in Primary's ledger to the repository filename version `20260920120000`, the practice already recorded for `20260909060754` and `20260909114354`;
   - (f) re-read Primary's FULL ledger using the same query as (b);
   - (g) rewrite `reports/evidence/primary-ledger-evidence.json` from that post-deployment reading — `project_ref`, `read_at`, `read_via`, `read_query`, `repository_head`, `migration_count`, `ledger_fingerprint` and the complete `ledger` array. The array must be what Primary reported, never a repository list standing in for a Primary one (GUARD-1);
   - (h) prove repository, local and Primary hold the same migration identities exactly;
   - (i) read the function-surface and structural-surface hashes FROM Primary itself, because those are the values Step 12 must write;
   - (j) run `pwsh -NoProfile -File scripts/check_database_parity.ps1` and `pwsh -NoProfile -File scripts/check_primary_ledger.ps1`, and record both results.
   **If any post-deployment operation fails, STOP immediately and report Primary's exact state as read.** Do not attempt opportunistic recovery, do not re-apply, and do not author a second migration to correct the first. This step runs only under an approved contract during execution; nothing is deployed while this contract is a Draft, and Secondary is never contacted.

12. **Check:** `_ORVION_CANONICAL/manifest.md`'s `Batch 6 surface coverage` line reads `13 of 77`. If it does, record Already Applied. Otherwise, AFTER Step 11 has completed, update that file by measurement only:
   - set the `Batch 6 surface coverage` line to `13 of 77`;
   - update `Last Completed` and `Next capability` together per `CR_LIFECYCLE.md §9` so that SPEC-203 becomes `Last Completed`, REPLACING the SPEC-202 entry rather than chaining it, and `Next capability` names Batch 6 Slice 13 ranked by `scripts/batch6_select_target.ps1`;
   - replace the standing sentence that Migration CI is OBSERVE ONLY until the first Batch-6 database slice compares it, with the outcome this slice measured;
   - REMEASURE every mutable fact in the `Live state:` sentence and write each from its measurement rather than by incrementing: migration count, latest migration identity, ledger fingerprint, function-surface hash and function count, structural-surface hash and object count, test-file count, declared pgTAP assertion total, and the catalog pair. The expected catalog result is `catalog_types` still **71** and `catalog_values` **621**, and each is written only once measurement returns exactly that; a measured value that differs from the expectation is a STOP, not a number to write down.
   Do not modify the `Narrative:` field. The `Live state:` sentence may claim Primary parity ONLY if Step 11 actually read Primary and proved it; if it did not, the sentence must say so plainly instead.

13. **Check:** `ai-map.json`'s `live_state` copies of `Last Completed`, `Active Change Request` and `Next capability` are equal by value to `_ORVION_CANONICAL/manifest.md`'s. If they already agree, record Already Applied. Otherwise regenerate `ai-map.json` with `pwsh -NoProfile -File scripts/generate-ai-map.ps1` and re-check. Run this regeneration after EVERY commit in this Change Request's lifecycle that changes the manifest, including the `Approve` and `Complete` transitions. The generator writes CRLF while Git stores this file LF under `core.autocrlf=true`, so normalise the regenerated file to LF before committing or `git diff --check` reports trailing whitespace on every line; the generator itself is out of scope and is not modified.

## Acceptance Criteria

- [ ] `_ORVION_CANONICAL/27_event_catalog.md` defines `user_deactivated`, `user_reactivated` and `user_identity_bound`, each at `Severity: security`, inside `# Organization And User Events`.
- [ ] `supabase/migrations/20260920120000_membership_authority_and_audit.sql` exists and registers those three codes in `public.catalog_values` under `event_type` at `sort_order` 932, 933 and 934.
- [ ] `public.users` carries exactly one `BEFORE INSERT OR UPDATE` trigger executing `app.guard_membership_authority` and exactly one `AFTER INSERT OR UPDATE` trigger executing `app.emit_membership_change`, and neither trigger names `DELETE`.
- [ ] `app.guard_membership_authority` calls `app.authorize`, `app.emit_membership_change` resolves its actor through `app.current_user_id()`, and neither new function grants `EXECUTE` to `PUBLIC`.
- [ ] `app.create_tenant_user` no longer contains a `record_event` call, and `app.emit_membership_change` is the only producer of `user_created`.
- [ ] `users_enforce_identity_binding` and all four RLS policies on `public.users` are byte-identical to their pre-change definitions, and `public.users` carries no `guard_write_capability` trigger.
- [ ] `supabase/tests/118_membership_authority_and_audit_test.sql` exists, declares `-- ATTACK-CLASSES:` from the closed vocabulary, contains at least one `throws_ok`, includes an `activate_membership` regression assertion whose claimant holds the `employee` role, and contains all four mutation controls named in this contract's Mutation Obligation.
- [ ] That file asserts exactly one `user_created` for the `aal2` RPC call, exactly one each of `user_deactivated`, `user_reactivated` and `user_identity_bound` for their transitions, and zero events for an UPDATE that changes only `full_name`, with each counted population proven non-empty.
- [ ] That file pins that an administrator deactivating their own membership emits `user_deactivated` with `actor_user_id` null, and states why.
- [ ] `supabase/tests/10_grant_model_test.sql`'s `MEAS-2` expected array contains `users`, its count wording reads TEN, and its description states why the population was allowed to rise.
- [ ] `supabase/tests/35_subscription_write_gate_test.sql` clears `request.jwt.claims` before the `identity administration still works` assertion.
- [ ] `supabase/tests/31_access_revocation_test.sql` clears `request.jwt.claims` immediately before its administrative deactivation, carrying a `SPEC-203` comment explaining why; its plan count, every assertion's SQL, expected value and description, and the claim it sets afterwards are unchanged from their state at the start of this Change Request.
- [ ] `supabase/tests/75_human_identity_family_test.sql` is byte-identical to its state at the start of this Change Request.
- [ ] `npx supabase test db` reports **0 failures**, and the number of assertions it executes equals the sum of the literal `plan(N)` declarations across `supabase/tests`.
- [ ] `reports/master/MASTER_GAP_REGISTER.md` carries `USR-1` and `USR-2` as resolved, `IDENT-2` as resolved by the same emitter, an OPEN `USR-3` row naming `user_permission_grants` and `user_branch_assignments`, and an OPEN `USR-4` row naming `is_platform_user` with its exact reopening trigger.
- [ ] `reports/master/MASTER_SURFACE_DISPOSITION.md` records `users` as `AUDITED-OPEN` / `ADVERSARIAL` citing `SPEC-203-membership-authority-and-audit`, and its Coverage summary agrees with its rows.
- [ ] `USR-4` is described as DEFER WITH TRIGGER with the same named trigger in `reports/master/MASTER_GAP_REGISTER.md`, in the `users` row's `Next` cell, and in this contract's Notes; no artifact describes it as an owner decision.
- [ ] `reports/master/MASTER_SURFACE_DISPOSITION.md`'s `Session` column definition names the immutable evidence artifact that owns the recorded audit evidence and admits a terminal Change Request where the repository deliberately wrote no session report; the `Findings` and `Next` definitions on that line are unchanged.
- [ ] `_ORVION_CANONICAL/manifest.md` is inside Check 5's 7000-character budget at every commit of this contract's lifecycle, including the Approve commit that adds the `Active Change Request` pointer and the Complete commit that rewrites `Last Completed`, and no entry belonging to an unrelated Change Request was trimmed to make room.
- [ ] `reports/README.md` and `_ORVION_CANONICAL/manifest.md`'s `Narrative:` field are byte-identical to their state at the start of this Change Request, and no new file exists under `reports/history/`.
- [ ] `scripts/verify_database.sql` pins `catalog_values` at **621** in all three places that state it, as an exact equality on a literal, with `CHECK 6a`'s `catalog_types` pin still **71** and every other check unchanged.
- [ ] The Execution Log records both directions of that repair causally: the pre-change file failing against the new clean-reset state with `expected 618 catalog_values, found 621`, and the updated file passing against the same state, with the three-row difference named as this contract's three `event_type` codes.
- [ ] `reports/evidence/primary-ledger-evidence.json` names `project_ref` `vrvtsxexkiiiivlkdxzp`, contains `20260920120000` in its `ledger` array, and its `migration_count` and `ledger_fingerprint` are consistent with that array.
- [ ] The repository migration filename set, the local `supabase_migrations.schema_migrations` set and the Primary ledger recorded in that evidence file contain the same migration identities.
- [ ] `_ORVION_CANONICAL/manifest.md` records Batch 6 coverage as `13 of 77`, names SPEC-203 as `Last Completed` in place of SPEC-202, and its `Live state:` sentence publishes the catalog pair as `71/621` with every mutable figure written from a post-deployment measurement.
- [ ] `ai-map.json`'s live_state copies of `Last Completed`, `Active Change Request` and `Next capability` match `_ORVION_CANONICAL/manifest.md` by value, and the file is stored with LF line endings.
- [ ] The Execution Log records the pre-deploy readiness gate's measured result for every one of its items, and records that the only repository-consistency failures standing at that moment were the three bounded classes named in Step 10.
- [ ] The Execution Log records the Migration CI comparison SPEC-173 deferred to the first Batch-6 database slice: the run identified by the exact candidate SHA, its `db reset`, pgTAP and smoke outcomes, and whether they agree with the local DATABASE evidence and the `orvion-acceptance` run for the same bytes, with any disagreement carried to `reports/master/MASTER_GAP_REGISTER.md` rather than resolved by preferring one side.
- [ ] No file outside this contract's Write Scope was created, modified or deleted — in particular `changes/SPEC-193-*.md`, `changes/SPEC-194-*.md` and `changes/SPEC-195-*.md` are byte-identical to their state at their respective `Cancel` commits and still `Cancelled`.

## Execution Log

[Appended by the executing agent after each run against this Change Request, before
IMPLEMENT is considered complete, per synchronization as defined in `CR_LIFECYCLE.md` §8
— this file is always implicitly in scope for this section.
Append-only — never edit or delete a prior entry, including a Blocked or Failed one.]

## Verification Notes

[Appended by the reviewing agent after independently re-checking the Execution Log
against the live repository state. Append-only — never edit or delete a prior entry.]

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

**Why this is two triggers and not one.** `app.emit_role_change` is a single AFTER trigger that both charges the step-up and records the fact. Copying it is wrong here for a measured reason: `public.users.is_active` is an input to `app.current_user_id()` and therefore to `app.has_permission`, so an authority check evaluated AFTER the statement is evaluated against a world the statement has already changed, and an administrator deactivating their own membership would be refused `permission denied: MANAGE_USERS`. `user_role_assignments` has no such self-reference, which is the property that does not transfer. Authority is a precondition and runs BEFORE; the record is a fact and runs AFTER. Measured under the prototype: at `aal2`, self-deactivation succeeds.

**Why the self-claim carve-out is admissible even though it reads `new`.** The repository's sixth Batch-6 rule forbids sourcing *authority* from the attacker's own image, and this carve-out does read `new.auth_user_id`. It is admissible only because it is not what decides the outcome: `users_enforce_identity_binding` independently requires the membership's email to match the bound identity's email in `auth.users`, which the attacker does not control. Attacked rather than argued — an administrator at `aal1` pointing an unclaimed executive membership at their own identity was refused `23514`; renaming the row under the same statement was still refused `23514`; moving `email`, `is_active` or the already-bound `auth_user_id` took the statement out of the carve-out and was refused `42501`; and an employee without `MANAGE_USERS` never reaches the carve-out at all because RLS refuses them first.

**Why the actor is resolved rather than passed as null.** `app.create_tenant_user` today looks up the acting membership and records it, so an emitter that always passed null would *lose* attribution while claiming to add auditing. The emitter therefore reuses `app.emit_role_change`'s own idiom, `app.current_user_id()`. Measured under the prototype: session-less platform INSERT → actor null (which is what WP-00 requires on that path); administrator at `aal2` through either door → the administrator's membership; employee self-claim → the claimant. One property falls out of the existing resolver and is pinned by an assertion rather than left to be rediscovered: an administrator deactivating their own membership records a null actor, because `app.current_user_id()` requires `is_active` and the AFTER trigger sees the post-image.

**DELETE is deliberately excluded.** `authenticated` holds no `DELETE` on `public.users` (measured: the grants are `INSERT`, `SELECT`, `UPDATE` only), and `public.events` carries `FOREIGN KEY (tenant_id, actor_user_id) REFERENCES users(tenant_id, id) ON DELETE RESTRICT`. There is no reachable tenant-user delete door and no measured defect on one, so `DELETE` has not earned inclusion merely because the sibling trigger names it.

**The sibling surfaces stay separate, and the boundary is mechanical.** `public.user_permission_grants` and `public.user_branch_assignments` were attacked during this slice and neither charges the step-up on direct DML: a `ceo` at `aal1` self-granted `VIEW_ADVANCED_DASHBOARDS`, moving `app.has_permission` for it from false to true, and self-assigned an additional branch. The same actor at the same `aal1` was refused `42501` on `public.user_role_assignments`, which proves the precedent works and that these are outliers rather than the norm. They are different surfaces, they are recorded as `USR-3`, and they are deliberately not repaired here; their defining migration is named in Out of Scope. One precision that must not be lost: the permission-grant door *did* emit an event, so that gap is step-up only, not audit.

**`is_platform_user` is recorded, not quietly fixed.** Measured: a tenant `ceo` at `aal1` set `is_platform_user = true` on their own row and it persisted, and the column is read by no function, no policy and no tracked consumer anywhere in this repository. It is therefore not currently exploitable, and inventing a meaning for it inside a slice about membership authority would be scope laundering. It is registered as `USR-4`, classified **DEFER WITH TRIGGER**, whose exact trigger is the first time any policy, function or application path reads that column. It is deliberately **not** an owner decision: nothing reads the column, so no business or compliance question has been reached, and its register row therefore carries an empty Owner Decision column. `AUDITED-OPEN` on the `users` row records only that a finding remains open on that surface; it carries no implication that a decision is owed. This contract does close the `aal1` half by consequence, because the guard charges on every column — stated here rather than left as an accidental side effect, per `AGENTS.md §5b`.

**What this contract owes to four cancelled predecessors, and what it does not inherit.** `SPEC-193`, `SPEC-194` and `SPEC-195` carried this engineering and were cancelled after execution proved dependency-closure failures in what they had frozen. `SPEC-197` carried it again, was hardened, approved on a non-vacuous automatic `APPROVAL_EVIDENCE: PASS`, and was then cancelled because its range could not be published at all — `CTRL-2A` treated the `Draft` at its range base as frozen authority, and the repair lay in a file its own Out of Scope forbade. None of the four was cancelled for a falsified finding.

Nothing is inherited on their authority. USR-1 and USR-2 were re-confirmed against `9380bce`: `public.users` carries three RLS policies calling `app.has_permission` and **zero** calling `app.authorize`, `app.create_tenant_user` still calls both `app.authorize` and `app.record_event`, and `public.users` still carries no emitter — only `moddatetime` and `users_enforce_identity_binding`. The blast radius, the consumer sweep and the `sort_order` choice were each re-measured rather than copied: `event_type` sort orders **932, 933 and 934** are free, the three event codes are absent from `catalog_values`, and `supabase/migrations/20260920120000_*` does not exist.

**How this contract avoids the defect that made `SPEC-195` unsatisfiable.** That contract's Step 10 moved `reports/README.md`'s live session pointer, its Step 13 moved the matching manifest `Narrative:` field, Check 10 compares the two by value, and its Primary gate — which admitted exactly three failure classes — sat between them. A fourth class, `STALE POINTER`, was therefore structurally guaranteed at the precise moment it was forbidden, and neither available escape was legal under its own frozen text. The lesson it recorded on cancellation was that a contract whose steps move two sides of a by-value consistency pairing must not place a gate forbidding that pairing's disagreement between them. This contract does not sequence around that pairing; it removes it. No session report is written, `reports/README.md` is untouched and named in Out of Scope, the manifest `Narrative:` field is explicitly not modified by Step 11, and the disposition row cites this Change Request as its evidence pointer — which Check 22 resolves through the repository-wide basename index it already uses, verified by reading the check rather than assumed. Evidence for the slice lives in this contract, in `118_membership_authority_and_audit_test.sql` and in Git, which is where `ENGINEERING_METHOD.md` and the `SPEC-160` precedent say it belongs.

**Migration CI is OBSERVED here, not changed.** `changes/SPEC-173-certified-evidence-names-its-context.md` left Migration CI *"OBSERVE ONLY until the first real Batch-6 database slice can compare it against acceptance by evidence"*, and the manifest still carries that standing sentence. This is that slice: it writes `supabase/migrations/**`, `supabase/tests/**` and `scripts/verify_database.sql`, which are Migration CI's own `push:` path filters, so `-Certify` derives it into the expected workflow set automatically. What `-Certify` does not do is compare the two runs' *content*, which is what SPEC-173 asked for; that comparison is an Acceptance Criterion against the Execution Log, and the manifest's standing sentence is replaced by its outcome in Step 11. One specific hypothesis to test rather than assume: `migration-ci.yml` resolves its CLI through `supabase/setup-cli@v3` pinned to **2.109.1**, while `orvion-acceptance` and local Finish resolve it from the lockfile. Observing that divergence is not reproducing a defect from it, so `.github/workflows/migration-ci.yml` is in Out of Scope. If the comparison reproduces a concrete disagreement, it earns its own Change Request.
