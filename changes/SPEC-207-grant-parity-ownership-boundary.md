# Change Request — SPEC-207

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make the structural-parity surface compare the grant state ORVION actually owns. `scripts/parity_surface.sql` hashes `service_role` table grants, a role the repository states in a migration that it deliberately does not manage, and whose baseline is set by a platform default ACL that differs between a hosted project and a local CLI stack. The result is a **standing false red** on the only live local↔Primary structural comparison this repository has. Narrow the `grants` surface to the roles the repository manages, prove that genuine `authenticated` and `anon` privilege drift is still refused, and leave the records truthful. **No migration, no product behaviour, and no write of any kind to Primary.**

## Business Reason

`PAR-5` was recorded by `SPEC-203` and escalated by `SPEC-206` to a High certification blocker. Measurement for this contract confirms the defect and **refutes part of its recorded causal story**, which is why this contract exists at the size it does.

What is confirmed: the `grants` surface diverges between local and Primary by exactly **333** rows, all of them `service_role`. What is newly measured is the ownership boundary, which had been inferred from the role name rather than read: the `postgres`-owned default ACL for schema `public` is `service_role=arwdDxtm` on Primary and `service_role=Dxtm` on local, and **no migration in this repository issues `alter default privileges` for `service_role` at all**. Neither baseline is repository-authored. The repository does author exactly two `service_role` TABLE grants, and **both are present and identical on both sides**, so the divergence contains no repository-owned fact.

What the standing red costs is not cosmetic. The `grants` surface exists because "a widened grant is a silent privilege escalation that no function hash can see". Because that surface is *already* red, a genuine `authenticated` escalation changes the reported verdict from `PRIMARY STRUCTURE DRIFT` to `PRIMARY STRUCTURE DRIFT` — measured, not argued. The false red actively masks the drift the surface was built to catch.

**This is a legitimate reopening, by the manifest's own rule rather than by preference.** `Next capability` states that the control-plane chapter is CLOSED and that reopening it requires newly earned evidence — "a real incident, a false green or **a false red**, **a measured material cost**, or a proven safety/governance gap", never a further search for theoretical optimizations. This contract is built on two of those four, both measured at this HEAD and recorded below, and on no optimization argument at all.

What this contract does **not** claim is that it unblocks `DATABASE` certification. It does not, and the recorded `PAR-5` row is wrong to say it would. The `DATABASE` profile's mandatory command is the **bare** `check_database_parity.ps1`, whose `$primaryProven` requires three caller-supplied Primary values that a bare call never has, so it returns **2** regardless of any grant state — reproduced at this HEAD with `$issues = 0`. That is a separate defect, recorded here as **`PAR-6`**, and it belongs to a control change with its own contract and an owner decision about whether recorded Primary evidence may stand in for a live read.

## Risks

- **Editing a detector to make it green.** The risk this contract must answer, because it is the one the repository forbids most plainly. It is answered by measurement of the ownership boundary and by negative controls that must still fire: a removed `authenticated` privilege and an added `anon` privilege each have to move the combined hash after the repair. A repair that only deleted red rows would pass neither.
- **Hiding a repository-owned `service_role` grant.** Stated rather than glossed. After this change, drift in the two repository-authored `service_role` table grants is not compared. That coverage is **not being lost, because it does not exist today**: Primary's default ACL grants `service_role` every privilege on every `public` table, so those rows are present on Primary whether or not the migration that grants them ever ran, and their absence there is unobservable. The residual is recorded as **`PAR-7`** with a reopening trigger rather than left unsaid.
- **Freezing an unreachable verification.** The defect that cancelled `SPEC-205`. Every command this contract's profile makes mandatory, and every command it names in `Additional Verification`, was EXECUTED before this text was frozen and each returned **exit 0**. The measured exits are in the Verification Write-Closure table below.
- **Leaving a published hash stale.** `check_database_parity.ps1` Check L5 compares `manifest.md`'s published structural hash against the live database, so narrowing the surface makes the manifest stale in the same instant. `manifest.md` is in Write Scope, and the staleness was reproduced in a disposable worktree before this text was frozen so that the requirement is measured rather than predicted.
- **Recording the capability as complete before it is complete.** `SPEC-203` shipped that defect. No Implementation Step here touches `Last Completed` or `Next capability`; an Acceptance Criterion requires that to remain true.
- **Widening into the neighbouring defect.** `PAR-6`'s repair would change `scripts/check_agent_continuity.ps1` or `check_database_parity.ps1`'s evidence contract. Both are named in Out of Scope and neither is edited.

## Supersedes / Depends On

None. `changes/SPEC-203-membership-authority-and-audit.md`, `changes/SPEC-205-slice-12-closure.md` and `changes/SPEC-206-slice-12-closure.md` are terminal contracts. This Change Request does not supersede, extend, amend or edit any of them, and requires no status change on any file. `SPEC-203` is cited as where `PAR-5` was found and `SPEC-206` as where it was escalated; their bytes are evidence and are never edited.

## Write Scope

- `changes/SPEC-207-grant-parity-ownership-boundary.md`
- `scripts/parity_surface.sql`
- `_ORVION_CANONICAL/manifest.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `scripts/check_database_parity.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-api-contract.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/check_primary_ledger.ps1`
- `scripts/verify_database.sql`
- `supabase/migrations/202607050200_restore_least_privilege_grant_model.sql`
- `supabase/migrations/202607054900_document_retention_and_storage_reconciliation.sql`
- `supabase/migrations/202607059800_capability_grants_are_per_user_not_only_per_role.sql`
- `supabase/tests/10_grant_model_test.sql`
- `reports/evidence/primary-ledger-evidence.json`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_REPOSITORY_HEALTH.md`
- `changes/SPEC-203-membership-authority-and-audit.md`
- `changes/SPEC-205-slice-12-closure.md`
- `changes/SPEC-206-slice-12-closure.md`
- `AGENTS.md`
- `GOVERNANCE.md`
- `ENGINEERING_METHOD.md`
- `CR_LIFECYCLE.md`

## Required Reading

- `scripts/parity_surface.sql` — the ten surfaces, and the `gr` CTE's stated purpose
- `scripts/check_database_parity.ps1` — Checks L4/P4 and L5, and the `exit 0 / 1 / 2` contract
- `supabase/migrations/202607050200_restore_least_privilege_grant_model.sql` — the ratified grant model, and line 31's statement that `service_role` is deliberately untouched
- `supabase/tests/10_grant_model_test.sql` — the grant model's own assertions, which name `anon` and `authenticated` only
- `reports/master/MASTER_GAP_REGISTER.md` — `PAR-3`, `PAR-5`, `GUARD-1`
- `reports/master/MASTER_EXECUTION_PLAN.md` — `PAR-3`'s closure, and the RLS `FORCE` decision at line 1271 that this contract must not disturb
- `CR_LIFECYCLE.md` §9 — which transition owns `Last Completed` and `Next capability`

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

- `pwsh -NoProfile -File scripts/check_primary_ledger.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Derived Applicability

| Predicate | Repository-derived fact | Result |
| --- | --- | --- |
| Consumer Closure | This contract changes a shared measurement file that a guard, a published manifest figure and two Master records interpret | APPLICABLE |
| Execution-Boundary Satisfiability | There is **no irreversible action**: no migration is authored or applied, and Primary is read only | NOT APPLICABLE |
| Permanent-Control Admission | No database control, trigger, policy, grant or guard is added, altered or removed. The change narrows what an existing comparison reads | NOT APPLICABLE |
| SPEC Allocation | This contract allocates a new repository engineering identity | APPLICABLE |

**The automatic evaluator returns `NOT APPLICABLE`, and that is the correct verdict rather than a gap.** Derived profiles are `REPOSITORY` only — `scripts/parity_surface.sql` is not in `Get-ControlSurface` and matches none of the `DATABASE` patterns, which are `supabase/migrations/`, `supabase/tests/`, `supabase/config.toml`, `scripts/verify_database.sql` and `reports/master/MASTER_DATABASE_` — no path is a control surface, nothing matches `^supabase/functions/`, and the declared `Irreversible Action Step` is `NONE`, so the gate returns before reading this section. `SPEC-198` created that outcome deliberately, to separate *"we did not look"* from *"we looked and it is fine"*. Forced applicability is **not** a valid control here: it would make `Execution-Boundary Satisfiability` and `Permanent-Control Admission` mandatory, so this contract's honest `NOT APPLICABLE` answers would read as self-exemption and the run would return `INDETERMINATE`. The evidence below is therefore offered for human review, not asserted as machine-verified.

### Verification Write-Closure

Every command this contract's profile makes mandatory, every command it names in `Additional Verification`, what each can render stale, and **its measured exit code, taken before this text was frozen**:

| Command | Source | Artifact it regenerates or requires fresh | In Write Scope? | Measured exit |
| --- | --- | --- | --- | --- |
| `scripts/check_repository_consistency.ps1` | REPOSITORY profile, mandatory | `manifest.md`, `ai-map.json` (Check 7 compares by value), `MASTER_GAP_REGISTER.md` (Check 21 freshness) | YES | **0** |
| `git diff --check` | REPOSITORY profile, mandatory | nothing; whitespace only | n/a | **0** |
| `scripts/check_primary_ledger.ps1` | `supabase-primary` capability Evidence, and Additional Verification | `reports/evidence/primary-ledger-evidence.json` | Not needed — measured CLEAN at this HEAD, and this contract applies no migration | **0** |
| `scripts/check_database_parity.ps1` with all three Primary values | Implementation Step 3, not a profile requirement | Check L5 reads `manifest.md`; Check L3 regenerates `MASTER_API_CONTRACT.md` into a temp file and byte-compares | `manifest.md` **YES**; `MASTER_API_CONTRACT.md` **YES** | **0** |

All four were executed in a disposable worktree at this HEAD with the candidate applied. The last row is the one `SPEC-203` got wrong and `SPEC-205` could not fix: both artifacts a parity run can stale are in Write Scope. The **bare** parity command is deliberately absent — it is not mandatory for a `REPOSITORY` profile, this contract does not add it, and it provably cannot return 0 (`PAR-6`).

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| the `grants` CTE of the shared surface file | `scripts/check_database_parity.ps1` Check L4/P4 — the **only** reader of `scripts/parity_surface.sql` | VERIFY | Established by search over the whole repository: no other script, workflow or document executes that file. The script itself is in Out of Scope and is not edited |
| the local and Primary structural hashes | `_ORVION_CANONICAL/manifest.md` `Live state:` line; Check L5 | WRITE | MEASURED: both move to `0c77972ecf1b45096cda327943a45c00` (3,029 objects) and become **equal**, so the line's "nine of ten" qualification and its two divergent hashes are replaced by one. Reproduced in a worktree: without this write Check L5 reports `MANIFEST STALE` and the script exits 1 |
| `PAR-5`'s status and its causal claim | `reports/master/MASTER_GAP_REGISTER.md` | WRITE | Resolved, and its escalation sentence corrected. It asserts that this grant difference is why no `DATABASE` contract can certify; that is false and is replaced by `PAR-6`, which is the real cause |
| the residual this repair accepts | `reports/master/MASTER_GAP_REGISTER.md` | WRITE | New `PAR-7`. A repair that knowingly stops comparing something must record it, with a trigger, rather than leave it implicit |
| the generated API contract | `reports/master/MASTER_API_CONTRACT.md`; Check L3 | VERIFY (in Write Scope as insurance) | MEASURED green both before and after the candidate, in the worktree run. It is generated from `pg_catalog` and this contract changes no database object, so it cannot drift — but a parity run byte-compares it, so it stays in scope rather than repeating `SPEC-203`'s exact failure |
| CI's view of this file | `.github/workflows/*` | UNAFFECTED | Established by search: **no workflow references `parity_surface.sql`, `check_database_parity.ps1`, parity or the structural hash at all**. Migration CI, ORVION Acceptance and Repository Consistency are all unaffected, and none can reach Primary |
| the recorded Primary ledger | `reports/evidence/primary-ledger-evidence.json`; Check 19 | UNAFFECTED | It records the ledger only — no structural or function hash — so narrowing the structural surface cannot stale it. MEASURED CLEAN at this HEAD |
| `PAR-3`'s closure claim and the RLS `FORCE` decision | `reports/master/MASTER_EXECUTION_PLAN.md` | UNAFFECTED | Read before designing. Line 808 says Check L4/P4 covers "ten surfaces" and it still does. Line 1271's "**not** to be changed" governs RLS `FORCE`, **not** grants, and no part of this contract touches RLS |
| `Active Change Request`, `Last Completed`, `Next capability` | `manifest.md`, `ai-map.json`, Check 7, Check 18 | WRITE | Per `CR_LIFECYCLE.md` §9 these move in the **`Complete`** transition, together, and **no Implementation Step touches them** |
| Check 5's 7000-character manifest budget | Check 5 | WRITE | MEASURED with CRLF normalised as the guard does: the manifest is **6,919**; this contract's `Live state:` rewrite brings it to **6,904**, and its `Active Change Request` pointer costs **46**, peaking at **6,950** |
| the grant model's own test authority | `supabase/tests/10_grant_model_test.sql`; `scripts/verify_database.sql` CHECK 5e | UNAFFECTED | Both assert `anon` and `authenticated` only — verified by reading them. Neither mentions `service_role`, so neither is weakened, and both are in Out of Scope. This is also why the residual needs `PAR-7`: nothing pins the two repository-authored `service_role` grants, and pinning them would touch `supabase/tests/`, which derives the `DATABASE` profile and is therefore unreachable until `PAR-6` is repaired |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: NOT APPLICABLE

Irreversible Action Step: NONE

No migration is authored, applied or re-applied. Primary is contacted READ-ONLY, and only to read the grant catalog, role attributes, default ACLs and surface hashes needed to establish the ownership boundary and to prove parity. No invariant is broken at any point, so there is no red window for a gate to fall inside.

### Permanent-Control Admission

Applicability: NOT APPLICABLE

No trigger, policy, function, grant or guard is added, altered or removed on either database. The change is to what an existing comparison reads. The control it belongs to — Check L4/P4 — was admitted under `PAR-3` and is neither re-admitted nor re-argued.

### SPEC Identity Allocation

Applicability: APPLICABLE

Derived mechanically, not chosen. The allocation cursor is **206**, the new-side identity of the newest allocation event on `origin/main`'s first-parent history. The candidate advances to **207**, which is unreserved by all three reservation queries: absent from the current tree (`git grep SPEC-207 HEAD` returns nothing), absent from every added or renamed contract path in reachable history, and absent from the content pickaxe (`git log --all -S 'SPEC-207'` returns nothing). `SPEC-1000` and `SPEC-1001` are older anomalies the cursor walk never reaches, by design. No numeric maximum, manual cursor, allowlist or hard-coded expectation was used, and **no future identifier is written into tracked text by this contract**.

## Implementation Steps

1. **Establish the ownership boundary from both sides, READ-ONLY on Primary.** Record each measured result: the project ref is `vrvtsxexkiiiivlkdxzp` and is NOT Secondary `brplkqmbzffpxqgkkdzo`; the per-grantee `(grantee, schema.table, privilege)` hash and row count for `authenticated`, `anon` and `service_role` on both sides; the `postgres`-owned default ACL for schema `public` on both sides; and `rolbypassrls` for `service_role` on both sides. Prove the containment direction rather than asserting it: the Primary subset consisting of `REFERENCES`/`TRIGGER`/`TRUNCATE` on every `public` table plus the DML on the two tables the repository explicitly grants must hash to **exactly** local's full `service_role` set. Identify every repository-authored `service_role` TABLE grant by searching the migrations, and record the statement and file for each. **If any differing row corresponds to a repository-authored grant, or if `authenticated` or `anon` differ at all, STOP** — the root cause is not what this contract states and the design must change before anything is edited.

2. **Narrow the `grants` surface.** In `scripts/parity_surface.sql`, restrict the `gr` CTE's grantee list to the roles the repository manages, and replace the CTE's comment with the measured ownership boundary: which roles are compared and why, that no migration sets `service_role`'s default privileges, that the two repository-authored `service_role` table grants are present on both sides but unobservable on Primary because its default ACL saturates the role, and the reopening trigger. No other CTE, no other line and no other file is touched.

3. **Prove parity, and prove the write-closure.** Run `scripts/parity_surface.sql` on local and, READ-ONLY, on Primary, and record all ten per-surface rows from each. The nine surfaces other than `grants` must be **byte-identical to their pre-change values**, and the `_combined` values from the two databases must be **equal**. Then run `pwsh -NoProfile -File scripts/check_database_parity.ps1` with all three Primary values read live from Primary in this run (GUARD-1), and record its full verdict and **exit code**. Record the measured Check L5 result before and after the manifest is updated, so that the write-closure is evidence rather than a claim.

4. **Mutation proof — four controls, each in a transaction that is rolled back.** For each: reset to the pristine state first, apply the mutation, run the detector while the mutant is present, and record the pristine and mutant `grants` and `_combined` hashes for both the pre-change and the post-change surface. (i) **AUTHENTICATED NEGATIVE** — revoke a real `authenticated` table privilege; the repaired surface MUST move `_combined` away from Primary's. (ii) **ANON NEGATIVE** — grant `anon` a table privilege it does not hold; the repaired surface MUST detect it, which also proves `anon` is still measured although its population is currently zero. (iii) **REPOSITORY-OWNED `service_role` NEGATIVE** — revoke one of the two repository-authored `service_role` privileges; the repaired surface does **not** move, which is the declared residual and must be recorded as such rather than presented as coverage. (iv) **PLATFORM-MANAGED CONTROL** — add a `service_role` table privilege of the kind the platform adds; the repaired surface must **not** move, and the pre-change surface must, which is the false-red this contract removes. Also record the pre-change verdict for (i): it must show that a genuine `authenticated` escalation left the reported verdict unchanged, because the surface was already red.

5. **Performance.** Time the surface query on local three times before and three times after, and record both means. No network call is added to the local parity calculation.

6. **Update `_ORVION_CANONICAL/manifest.md`'s `Live state:` line** to publish the single structural-surface hash and object count now identical on both sides, replacing the two divergent values and the "nine of ten" qualification, and remove the `PAR-5` pointer from that sentence. Re-run `check_database_parity.ps1` with the three Primary values and record that Check L5 is green and the exit code is **0**. No other line of the manifest is touched, and neither `Last Completed` nor `Next capability` moves.

7. **Update `reports/master/MASTER_GAP_REGISTER.md`.** Mark `PAR-5` resolved, naming what was changed and the measured ownership evidence, and **correct rather than delete** its escalation claim that this grant difference is why no `DATABASE` contract can certify. Add **`PAR-6`** — the `DATABASE` profile's mandatory verification is the bare parity command, which cannot return 0 by construction, so no `DATABASE`-profile contract can be certified and repairing `PAR-5` does not change that; classify it as requiring an owner decision and do not repair it here. Add **`PAR-7`** — the two repository-authored `service_role` TABLE grants are pinned by no control, DEFER WITH TRIGGER, with the note that pinning them requires `supabase/tests/`, which derives the `DATABASE` profile and is blocked by `PAR-6`. Preserve every existing row's text per the file's never-delete rule, and add a NEW dated entry to the freshness header with the previous one demoted to `Previously:`. `USR-3` and `USR-4` remain OPEN and are not reworded or reclassified.

8. **Check:** `ai-map.json`'s `live_state` copies of `Last Completed`, `Active Change Request` and `Next capability` are equal by value to the manifest's. If they agree, record Already Applied. Otherwise regenerate with `pwsh -NoProfile -File scripts/generate-ai-map.ps1` and re-check. Run this after EVERY commit in this lifecycle that changes the manifest, including the `Approve` and `Complete` transitions. The generator writes CRLF while Git stores this file LF, so normalise to LF before committing or `git diff --check` reports trailing whitespace on every line.

**Deliberately NOT an Implementation Step:** `_ORVION_CANONICAL/manifest.md`'s `Last Completed` and `Next capability`. `CR_LIFECYCLE.md` §9 assigns both to the **`Complete`** transition, moved together with clearing `Active Change Request`. `SPEC-203` wrote them during `In Progress` and thereby published its own completion while still active.

**Deliberately NOT in this contract:** any repair of `PAR-6`, any change to `supabase/tests/`, and Batch 6 Slice 13.

## Acceptance Criteria

- [ ] `scripts/parity_surface.sql`'s `gr` CTE compares `authenticated` and `anon` and no longer includes `service_role`, and its comment states the measured ownership boundary and the reopening trigger.
- [ ] The nine surfaces other than `grants` are byte-identical to their values before the change, on local: `functions` `f791acdba3e91462b1625ab8a723db4d` (298), `triggers` `0b9a3d18177ac8107e66e2a25f4c686a` (287), `policies` `8e641292a1ab4d54b4decdb58c0dfc06` (124), `constraints` `cb611f191ac997f93db8ad599d48984b` (510), `columns` `1c59fd3b11a306c83a5f8bc48e42e321` (1113), `views` `10bb212ab2ffe297c93a6a06f0263389` (16), `indexes` `3973f9c9dab7d4ca8cfc4b3466bd859c` (294), `status_transitions` `db2165c755f233c0772b6c633e29d39c` (115), `rls_enabled` `fbd0240f553f151b9ef55af484eb52b5` (78).
- [ ] The `grants` surface hash is equal on local and Primary, and the `_combined` hash and object count are equal on local and Primary, each value read from its own database in this run.
- [ ] `pwsh -NoProfile -File scripts/check_database_parity.ps1` supplied with all three Primary values read live FROM Primary reports `DATABASE PARITY: CLEAN` and **exit 0**, with Check L4/P4 printing `Primary's structural surface matches local` and Check L5 green.
- [ ] The Execution Log records, for the AUTHENTICATED mutation, that the **pre-change** surface left the reported verdict unchanged while the **post-change** surface moved `_combined` away from Primary's — the masking this contract removes, measured on both sides of the change.
- [ ] The ANON mutation moves the repaired `grants` row count from 194 to 195 and changes `_combined`.
- [ ] The PLATFORM-MANAGED mutation leaves the repaired `grants` and `_combined` hashes unchanged, and is recorded as having changed the pre-change surface.
- [ ] The REPOSITORY-OWNED `service_role` mutation is recorded as **not detected** by the repaired surface, with the reason it was never detectable across this bridge, and is registered as `PAR-7` rather than described as covered.
- [ ] Every mutation is recorded as applied, executed with the mutant present, rolled back, and followed by a pristine re-measurement equal to the pre-mutation value.
- [ ] `_ORVION_CANONICAL/manifest.md` publishes one structural-surface hash with its object count, states that it is identical on both sides, and no longer qualifies parity as nine of ten surfaces or points at `PAR-5` for the tenth.
- [ ] `_ORVION_CANONICAL/manifest.md` is inside Check 5's 7000-character budget, measured CRLF-normalised, at every commit of this contract's lifecycle including the Approve commit.
- [ ] No Implementation Step modified `_ORVION_CANONICAL/manifest.md`'s `Last Completed` or `Next capability`; both move only in the `Complete` transition, together with clearing `Active Change Request`.
- [ ] `reports/master/MASTER_GAP_REGISTER.md` marks `PAR-5` resolved with its escalation claim corrected rather than deleted, records `PAR-6` as the actual `DATABASE`-certification blocker needing an owner decision, records `PAR-7` as the accepted residual with a trigger, preserves all prior text, and carries a NEW dated freshness entry with the previous one demoted to `Previously:`.
- [ ] `USR-3` and `USR-4` remain OPEN and otherwise unchanged, and Batch 6 Slice 13 is neither opened nor drafted.
- [ ] `reports/master/MASTER_API_CONTRACT.md` is byte-identical to a fresh run of its generator, and was not hand-edited.
- [ ] `pwsh -NoProfile -File scripts/check_primary_ledger.ps1` reports `RECOVER-1 LEDGER EVIDENCE: CLEAN`.
- [ ] No file under `supabase/` was created, modified or deleted, and no migration was authored or applied.
- [ ] The Execution Log records that Primary was contacted READ-ONLY only, states that **no INSERT, UPDATE, DELETE, DDL, GRANT, REVOKE or migration-apply call was issued to it**, and records Secondary `brplkqmbzffpxqgkkdzo` as never contacted.
- [ ] The surface query's measured runtime does not regress, and no network call is added to the local parity calculation.
- [ ] `pwsh -NoProfile -File scripts/check_repository_consistency.ps1` reports `REPOSITORY CONSISTENCY: CLEAN`.
- [ ] No file outside this contract's Write Scope was created, modified or deleted.

## Execution Log

[Appended by the executing agent after each run against this Change Request, before
IMPLEMENT is considered complete, per synchronization as defined in `CR_LIFECYCLE.md` §8
— this file is always implicitly in scope for this section.
Append-only — never edit or delete a prior entry, including a Blocked or Failed one.]

## Verification Notes

[Appended by the reviewing agent after independently re-checking the Execution Log
against the live repository state. Append-only — never edit or delete a prior entry.]

---

## Review Gate

[Completed by whoever performs the Review — the executing agent under autonomous completion
(`CR_LIFECYCLE.md` §5), otherwise a human. Do not mark Status as Complete until every item below
is checked.]

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as
      Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's
      Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.
