# Change Request — SPEC-208

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make DATABASE certification reachable again without weakening it. The `DATABASE` profile makes `scripts/check_database_parity.ps1` mandatory and invokes it **bare**, while listing the three Primary values that command requires as `Deferred` EXTERNAL evidence — so the profile demands a command pass and, in the same breath, declares the evidence it needs unreachable from a local process. Keep parity mandatory, keep it fail-closed, and satisfy it from an **attributable recorded Primary reading** that a local `-Finish` can validate. **No Primary mutation, no credential in any local process, and no second parity implementation.**

## Business Reason

`PAR-6` was recorded by `SPEC-207` and is reproduced here end to end, on a disposable DATABASE-profile contract with a healthy local database and a healthy Primary:

| Step | Result |
| --- | --- |
| `npx supabase db reset` · `npx supabase test db` · `scripts/verify_api_end_to_end.ps1` · `npx supabase test db` · `scripts/verify_database.sql` | **all PASS** |
| mandatory `pwsh -NoProfile -File scripts/check_database_parity.ps1` (bare) | **exit 2** — `PRIMARY UNPROVEN`, with Check L1, L3 and L5 all green and **zero issues** |
| `-Finish` | `MANDATORY_VERIFICATION_FAILED`, `CERTIFY: FAILED`, **no receipt** |
| the SAME local state, with the three values read live from Primary | **exit 0**, `DATABASE PARITY: CLEAN` |

The failure is therefore **evidence transport, not database drift** — the last row is the same database, the same repository and the same Primary, differing only in whether the three values reached the engine.

**The fail-closed behaviour is not the defect and is not touched.** `AUD-05` made "not measured" stop counting as "passed", and `$primaryProven` is how it did that. This contract does not relax it; it supplies the values it asks for.

**A live read from `-Finish` is not the answer, and that is settled repository authority rather than a preference.** `check_primary_ledger.ps1`'s own header records that a live read was evaluated first and rejected: `.mcp.json` exposes `supabase-primary` as an HTTP endpoint reachable by the agent and not by a script, no `SUPABASE_ACCESS_TOKEN` / `SUPABASE_DB_PASSWORD` / `PGPASSWORD` exists in the environment, and the CLI is not linked to a project — and `AGENTS.md` states that credentials remain external to Git. `RECOVER-1` already chose recorded evidence over a faked live read for the ledger. This contract extends that same choice to the other two parity facts instead of inventing a second policy for them.

**`ENGINEERING_METHOD.md §4` already prescribes the right shape** — "read Primary ledger, function hash, and `_combined` structure hash independently from Primary; run `scripts/check_database_parity.ps1`" — and the profile simply did not implement it, dropping the three values the method says to read. What changes here is the profile, so that it executes the method it claims to.

**Ledger evidence alone is NOT parity, and that was measured rather than assumed.** Editing an existing migration leaves every ledger identity unchanged, so `check_primary_ledger.ps1` still passes — while local moved to 299 functions (`ea7e69af…`) and 3,030 objects (`b830fa5e…`). Only the two surface hashes caught it. Collapsing ledger parity into structural parity would therefore have shipped a guard that cannot see a rewritten function body, which is `PAR-1`'s exact defect.

## Risks

- **Laundering the evidence class.** The risk that matters most here, because the failure would be invisible. The adapter never contacts Primary and never says it did: it prints `evidence class: a RECORDED Primary reading, not a live one`, the profile's `Deferred` note states that this run validated a record rather than reading Primary, and `GUARD-1`'s residual — no repository-local mechanism can prove the values came from Primary — is restated rather than quietly dropped. A control suite assertion requires that wording to be present on the accepting path.
- **A stale record certifying a moved database.** Answered causally, not by a clock. Reproduced: with the recorded Primary values still correct, changing one existing migration and resetting made the adapter report `PRIMARY FUNCTION DRIFT` and `PRIMARY STRUCTURE DRIFT` and exit 1. A wall-clock TTL was rejected because it would fail evidence that is still true and pass evidence that is not.
- **Becoming a second parity implementation.** The adapter computes no hash and compares no surface. `check_primary_ledger.ps1` is **invoked**, not restated; `check_database_parity.ps1` stays the one comparison engine and is **byte-unchanged**; `parity_surface.sql` stays the one structural definition.
- **Making an existing name lie.** `reports/evidence/primary-ledger-evidence.json` gains four surface fields and is NOT renamed, deliberately: 34 files reference that path or `check_primary_ledger.ps1`, fourteen of them terminal contracts and history reports that may never be edited, so a rename would leave the repository permanently disagreeing with its own immutable record. The validator keeps its name because what it validates — the ledger — is unchanged; the new facts are carried by a separately named adapter and a bumped `schema_version`.
- **Breaking the guard that runs in CI.** `check_repository_consistency.ps1` Check 19 executes `check_primary_ledger.ps1`, and that job has no Docker. The ledger validator is therefore left Docker-free and unchanged, and the composition lives in the adapter, which only the DATABASE profile's `-Finish` runs.
- **Freezing an unreachable verification.** Every command this contract's profiles make mandatory, and the command it names in `Additional Verification`, was EXECUTED with these changes applied in a disposable worktree before this text was frozen. The measured exits are in the Verification Write-Closure table.

## Supersedes / Depends On

None. `SPEC-207` closed `PAR-5` and recorded `PAR-6`; it is terminal and is neither edited nor reopened.

## Write Scope

- `changes/SPEC-208-parity-evidence.md`
- `scripts/check_database_parity_evidence.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `reports/evidence/primary-ledger-evidence.json`
- `ENGINEERING_METHOD.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `scripts/check_database_parity.ps1`
- `scripts/parity_surface.sql`
- `scripts/check_primary_ledger.ps1`
- `scripts/test_primary_ledger_guard.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-api-contract.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/verify_database.sql`
- `.github/workflows/agent-control.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/orvion-acceptance.yml`
- `changes/SPEC-207-grant-parity-ownership-boundary.md`
- `changes/SPEC-206-slice-12-closure.md`
- `AGENTS.md`
- `GOVERNANCE.md`
- `CR_LIFECYCLE.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`

## Required Reading

- `scripts/check_database_parity.ps1` — `$primaryProven`, and the `exit 0 / 1 / 2` contract that must not be weakened
- `scripts/check_primary_ledger.ps1` — its header's "design B, chosen on constraints, not taste", and the four properties that make recorded evidence stronger than a pasted number
- `scripts/check_agent_continuity.ps1` — `Get-ProfileEvidence`'s DATABASE arm, the `Evidence` command on an `EXTERNAL_EVIDENCE` capability, and `Invoke-Verification`
- `scripts/check_repository_consistency.ps1` — Check 19 executes the ledger validator, and Check 20's CI-1 input list
- `ENGINEERING_METHOD.md §4` — the database protocol this profile is supposed to execute
- `reports/master/MASTER_GAP_REGISTER.md` — `PAR-6`, `PAR-1`, `PAR-3`, `RECOVER-1`, `GUARD-1`, `AUD-05`
- `AGENTS.md` — credentials remain external to Git

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

- `pwsh -NoProfile -File scripts/check_database_parity_evidence.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Derived Applicability

| Predicate | Repository-derived fact | Result |
| --- | --- | --- |
| Consumer Closure | The Write Scope names `scripts/check_agent_continuity.ps1` and `scripts/test_agent_continuity.ps1`, both control surfaces, so the `CONTROL` profile is derived | APPLICABLE |
| Execution-Boundary Satisfiability | The change alters what a mandatory verification executes, so the order in which invariants hold must be stated | APPLICABLE |
| Permanent-Control Admission | A new permanent control is added: `scripts/check_database_parity_evidence.ps1` | APPLICABLE |
| SPEC Allocation | This contract allocates a new repository engineering identity | APPLICABLE |

### Verification Write-Closure

Every command these profiles make mandatory, every command named in `Additional Verification`, what each can render stale, and **its measured exit code with these changes applied, taken before this text was frozen**:

| Command | Source | Artifact it regenerates or requires fresh | In Write Scope? | Measured exit |
| --- | --- | --- | --- | --- |
| `scripts/check_repository_consistency.ps1` | REPOSITORY, mandatory | `manifest.md`, `ai-map.json` (Check 7), `MASTER_GAP_REGISTER.md` (Check 21); Check 19 executes the ledger validator against the evidence file | YES | **0** |
| `git diff --check` | REPOSITORY, mandatory | nothing; whitespace only | n/a | **0** |
| `scripts/test_agent_continuity.ps1` | CONTROL, mandatory | nothing; sandboxed, with `npx` and `docker` stubbed on PATH | YES | **0** |
| `scripts/test_cold_start_state_guard.ps1` | CONTROL, mandatory | nothing | n/a | **0** |
| `scripts/test_status_contradiction_guard.ps1` | CONTROL, mandatory | nothing | n/a | **0** |
| `scripts/test_primary_ledger_guard.ps1` | CONTROL, mandatory | nothing; it mutation-tests the ledger validator, which this contract leaves unchanged | n/a | **0** |
| `scripts/test_future_date_guard.ps1` | CONTROL, mandatory | nothing | n/a | **0** |
| `scripts/check_primary_ledger.ps1` | `supabase-primary` capability Evidence | `reports/evidence/primary-ledger-evidence.json` | YES | **0** |
| `scripts/check_database_parity_evidence.ps1` | Additional Verification | reads the evidence file; runs the parity engine, whose Check L5 reads `manifest.md` and whose Check L3 regenerates `MASTER_API_CONTRACT.md` into a temp file | evidence file and `manifest.md` **YES**; the API contract is unchanged by this contract and was measured green | **0** |

Naming the adapter in `Additional Verification` is deliberate: this contract's profiles are `CONTROL` and `REPOSITORY`, so nothing else would execute the thing being built. `-Finish` therefore exercises the repair itself. It was run before freezing and returned **0**; the bare `check_database_parity.ps1` is **not** named anywhere, because it provably cannot return 0.

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| the DATABASE profile's mandatory parity command | `Get-ProfileEvidence`; `Finish-Checks`; every future DATABASE contract | WRITE | The bare call is replaced by the adapter. Parity stays mandatory and stays fail-closed; only the source of the three values changes |
| the control suite's DATABASE assertions | `scripts/test_agent_continuity.ps1` assertions 101 and 103 | WRITE | Both name the mandatory command by path, so both are retargeted. MEASURED: 103's MUST-ACCEPT passed before only because the fixture stubs the parity script to `exit 0` — which is why this profile defect stayed latent since `SPEC-189` |
| the evidence record's schema | `reports/evidence/primary-ledger-evidence.json`; `check_primary_ledger.ps1`; Check 19 | WRITE | Four fields added and `schema_version` bumped to 2. The ledger validator reads six named fields and ignores the rest, so it is unchanged and Check 19 still passes — MEASURED, not assumed |
| the ledger validator's own contract | `scripts/check_primary_ledger.ps1`; `scripts/test_primary_ledger_guard.ps1`; Check 19 in CI | UNAFFECTED | Both named in Out of Scope. It is COMPOSED by the adapter, never reimplemented, and left Docker-free because Check 19 runs it in CI where no Docker exists |
| the parity engine | `scripts/check_database_parity.ps1` | UNAFFECTED | Named in Out of Scope and byte-unchanged. It remains the one comparison authority, now reached with real values |
| the documented database protocol | `ENGINEERING_METHOD.md §4` | WRITE | Amended to describe the implementation accurately, including that a deploying contract must carry the evidence file in its Write Scope. It is NOT rewritten to say Primary need not be read |
| CI's view of these files | `.github/workflows/agent-control.yml` | UNAFFECTED | It triggers on every push and pull_request with no path filter, so the new control suite assertions run on every change. No workflow edit is needed and none is made |
| Check 20's CI-1 required-trigger list | `scripts/check_repository_consistency.ps1` | UNAFFECTED | That list covers the inputs *that* guard reads. It already names the evidence file and the ledger validator; the adapter is not read by that guard, only by `-Finish` |
| `PAR-6`'s status | `reports/master/MASTER_GAP_REGISTER.md` | WRITE | Resolved, with the reproduction and the residual recorded |
| `Active Change Request`, `Last Completed`, `Next capability` | `manifest.md`, `ai-map.json`, Checks 7 and 18 | WRITE | Per `CR_LIFECYCLE.md` §9 these move in the **`Complete`** transition, together, and **no Implementation Step touches them** |
| Check 5's 7000-character manifest budget | Check 5 | WRITE | MEASURED CRLF-normalised BEFORE freezing, and it decided this contract's filename. The manifest stands at **6,960**; the `Active Change Request` pointer replaces `None`, so the peak is reached at the **Approve** commit — before any Implementation Step could trim anything. A descriptive 66-character path peaked at **7,022**, over budget; `changes/SPEC-208-parity-evidence.md` (35) peaks at **6,991**, inside it. No entry belonging to another Change Request is trimmed, and at `Complete` the pointer clears and `Last Completed` is replaced by this contract's own, shorter, entry |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

No migration is authored, applied or re-applied, and Primary is contacted READ-ONLY to refresh the recorded reading. The one ordering constraint that matters is internal: the profile stops accepting the bare command at Step 2, and the adapter that replaces it must already exist, so Step 1 creates it.

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| the DATABASE profile names a command that exists on disk | BEFORE_COMPLETION | Step 2 | Step 2 | Step 8 |
| the control suite agrees with the profile it guards | BEFORE_COMPLETION | Step 2 | Step 3 | Step 8 |
| the evidence record satisfies the adapter's admissibility rules | BEFORE_COMPLETION | Step 2 | Step 4 | Step 8 |
| Check 19 still validates the evidence record in CI | BEFORE_COMPLETION | Step 4 | Step 4 | Step 8 |
| repository consistency is CLEAN | BEFORE_COMPLETION | NONE | NONE | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: No, and the alternatives were tested rather than dismissed. `check_primary_ledger.ps1` cannot be widened to carry the surface hashes because Check 19 executes it inside CI, where no Docker and no local database exist; `check_database_parity.ps1` cannot read the evidence itself without becoming the second thing it is not (its Primary values are caller-supplied by design, GUARD-1). What is missing is transport between two mechanisms that each already work.
Existing Mechanism: the `EXTERNAL_EVIDENCE` capability's `Evidence` command, already used to make `check_primary_ledger.ps1` mandatory whenever `supabase-primary` is declared. This contract reuses that pattern's shape rather than inventing one.
Added Property: a local process can prove that the recorded Primary reading — ledger, function surface and structural surface — still describes the database this repository generates, and refuses certification when it does not.
Causal Negative: reproduced before this text was frozen. With a healthy local database and a healthy Primary, the bare mandatory command returned **exit 2 with `$issues = 0`** and `-Finish` ended `MANDATORY_VERIFICATION_FAILED` with no receipt; supplying the three values to the same database returned **exit 0**.
Positive Test Design: a DATABASE-profile Finish whose whole protocol succeeds reaches `LOCAL_CERTIFY: READY` with `PASS: pwsh -NoProfile -File scripts/check_database_parity_evidence.ps1` in its output (control suite assertion 103), and the adapter run directly against well-formed evidence exits 0 and prints its evidence-class disclaimer (assertion 103d).
Negative Test Design: eight refusals, each attributable to the adapter's own evidence handling because the ledger validator and the parity engine are stubbed — missing evidence, evidence naming Secondary, a missing surface hash, a malformed surface hash, a refusing ledger authority, and exit-code propagation of 1 and of 2 (assertions 103e–103k).
Non-Empty Population Obligation: the accepting cases must run against a real evidence record carrying both surface hashes and a real `project_ref`, not an empty or absent file; assertion 103d supplies one, and Step 5 additionally runs the adapter against the repository's own refreshed record.
Mutation Obligation: the mandatory DATABASE command must be the adapter, and a failing adapter must fail the Finish — proven by stubbing it to `exit 9` and requiring `FAILED: …check_database_parity_evidence.ps1 (exit 9)` with no receipt (assertion 101). `exit 2` must propagate as **2** and not be laundered into 1 or 0 (assertion 103k).
Post-Implementation Proof Obligation: the disposable DATABASE-profile contract that reproduced `PAR-6` must be re-run with the repair in place and reach `LOCAL_CERTIFY: READY`, and the semantic-freshness negative — change one existing migration, reset, and require the recorded Primary values to stop matching — must be recorded in the Execution Log with its measured hashes.

## Implementation Steps

1. **Create `scripts/check_database_parity_evidence.ps1`.** It validates the recorded Primary reading and hands its three values to the existing parity engine, propagating that engine's exit code exactly. It must compute no hash, compare no surface, and invoke `scripts/check_primary_ledger.ps1` rather than restate any of its rules. Its header states the deadlock it resolves, why evidence rather than a live read, the live-read/recorded/local-validation ownership split, and the `GUARD-1` residual it does not close.

2. **Point the `DATABASE` profile at it.** In `scripts/check_agent_continuity.ps1`, replace the bare `scripts/check_database_parity.ps1` entry in `Get-ProfileEvidence`'s `DATABASE` `Local` list with the adapter, and rewrite that profile's `Deferred` note so it states that the three values are read LIVE at the execution boundary and RECORDED, and that the run validated the record rather than contacting Primary. No other profile is touched.

3. **Make the control suite agree with the profile it guards.** In `scripts/test_agent_continuity.ps1`: add the adapter to the DATABASE fixture stubs; retarget assertions 101 and 103 to the command the profile now runs; and add the adapter's own cases — one MUST-ACCEPT and the negatives named in the Permanent-Control Admission — with the ledger validator and the parity engine stubbed so that every refusal is attributable to the adapter.

4. **Refresh `reports/evidence/primary-ledger-evidence.json` from a live READ-ONLY Primary read.** Record the ledger, the function-surface hash and count, and the structural-surface hash and object count, all read in one session from `vrvtsxexkiiiivlkdxzp` — the function surface with `check_database_parity.ps1`'s own Check L2/P2 expression and the structure with `scripts/parity_surface.sql`, the same file local runs. Bump `schema_version`, set `repository_head` to a commit that is an ancestor of HEAD, and state in the record that no write of any kind was issued to Primary and that Secondary was not contacted. **Verify the project ref before reading, and issue no INSERT, UPDATE, DELETE, DDL, GRANT, REVOKE or migration-apply call.**

5. **Prove it, positively and negatively, and record every measurement.** Run the adapter against the refreshed record and record its verdict and exit code. Then run the negative matrix, each case restored afterwards: missing evidence; `project_ref` naming Secondary; a missing surface hash; a malformed surface hash; a hand-edited ledger fingerprint; a dropped ledger entry; a non-ancestor `repository_head`; a wrong recorded function hash; a wrong recorded structural hash. Then prove semantic freshness causally: change one existing migration so ledger identities are unchanged, `npx supabase db reset`, and require the still-correct recorded Primary values to be reported as drift — then restore the migration, reset again, and re-measure the accepting case.

6. **Prove the DATABASE lifecycle end to end.** In a disposable worktree, run the same minimal DATABASE-profile contract that reproduced `PAR-6` and record that it now reaches `LOCAL_CERTIFY: READY`, naming the adapter among its PASS lines. Record also the pre-deploy shape: with a migration in the repository that Primary has not run, the ledger authority refuses and the adapter exits non-zero, which is why a deploying contract must refresh this record after deployment and carry it in its Write Scope.

7. **Amend `ENGINEERING_METHOD.md §4` to describe what now exists** — the three values are read live at the execution boundary and recorded; `-Finish` validates that record and runs the one parity engine against it; parity stays mandatory and fail-closed; a deploying contract carries the evidence file in its Write Scope. Do **not** write that Primary need not be read. Then update `reports/master/MASTER_GAP_REGISTER.md`: mark `PAR-6` resolved with the reproduction, the chosen design and the residual, add a NEW dated freshness entry with the previous one demoted to `Previously:`, and leave `PAR-7`, `USR-3` and `USR-4` OPEN and otherwise unchanged. Do not touch `_ORVION_CANONICAL/manifest.md` in this step: its budget peak is reached at the `Approve` commit and was measured inside budget before this text was frozen.

8. **Check:** `ai-map.json`'s `live_state` copies of `Last Completed`, `Active Change Request` and `Next capability` are equal by value to the manifest's. If they agree, record Already Applied; otherwise regenerate with `pwsh -NoProfile -File scripts/generate-ai-map.ps1`, normalising to LF, and re-check. Run this after every commit in this lifecycle that changes the manifest, including the `Approve` and `Complete` transitions.

**Deliberately NOT an Implementation Step:** `_ORVION_CANONICAL/manifest.md`'s `Last Completed` and `Next capability`, which `CR_LIFECYCLE.md` §9 assigns to the **`Complete`** transition.

**Deliberately NOT in this contract:** renaming the evidence file or the ledger validator; formalizing Verification Write-Closure as methodology; and Batch 6 Slice 13, which is not opened, drafted or begun.

## Acceptance Criteria

- [x] `scripts/check_database_parity_evidence.ps1` exists, computes no hash and compares no surface, invokes `scripts/check_primary_ledger.ps1` and `scripts/check_database_parity.ps1` rather than reimplementing either, and exits with the parity engine's exit code unchanged.
- [x] `Get-ProfileEvidence`'s `DATABASE` profile lists the adapter as its mandatory parity verification and no longer lists the bare `scripts/check_database_parity.ps1`.
- [x] `scripts/check_database_parity.ps1`, `scripts/parity_surface.sql`, `scripts/check_primary_ledger.ps1` and `scripts/test_primary_ledger_guard.ps1` are byte-identical to their state at this contract's baseline.
- [x] `reports/evidence/primary-ledger-evidence.json` carries `function_surface_hash`, `function_count`, `structural_surface_hash` and `structural_object_count`, each read READ-ONLY from `vrvtsxexkiiiivlkdxzp` in this run, with `schema_version` bumped and `repository_head` an ancestor of HEAD.
- [x] `pwsh -NoProfile -File scripts/check_database_parity_evidence.ps1` reports `PRIMARY PARITY EVIDENCE: CLEAN` and **exit 0** against the refreshed record, and its output states that it never contacted Primary.
- [x] The Execution Log records all nine negative cases with their measured exit codes, each refused for its own stated reason, and records that the accepting case was re-measured to 0 afterwards.
- [x] The Execution Log records the semantic-freshness proof with measured hashes: one existing migration changed, ledger identities unchanged, local moving to a different function-surface and structural-surface hash, and the still-correct recorded Primary values reported as drift with exit 1.
- [x] The Execution Log records that the disposable DATABASE-profile contract which reproduced `PAR-6` reaches `LOCAL_CERTIFY: READY` with the repair in place, naming the adapter among its PASS lines.
- [x] `pwsh -NoProfile -File scripts/test_agent_continuity.ps1` passes with zero failures, including the retargeted assertions 101 and 103 and the adapter's own accepting and refusing cases.
- [x] `pwsh -NoProfile -File scripts/check_primary_ledger.ps1` reports `RECOVER-1 LEDGER EVIDENCE: CLEAN`, proving the extended record is still valid to the unchanged ledger authority.
- [x] `ENGINEERING_METHOD.md §4` states that the three Primary values are read live at the execution boundary and recorded, that `-Finish` validates that record and runs the parity engine against it, and that a deploying contract carries the evidence file in its Write Scope — and nowhere states that Primary need not be read.
- [x] `reports/master/MASTER_GAP_REGISTER.md` marks `PAR-6` resolved with its reproduction and residual recorded, carries a NEW dated freshness entry with the previous one demoted to `Previously:`, and leaves `PAR-7`, `USR-3` and `USR-4` OPEN and otherwise unchanged.
- [x] `_ORVION_CANONICAL/manifest.md` is inside Check 5's 7000-character budget, measured CRLF-normalised, at every commit of this contract's lifecycle including the Approve commit.
- [x] No Implementation Step modified `_ORVION_CANONICAL/manifest.md`'s `Last Completed` or `Next capability`; both move only in the `Complete` transition.
- [x] The Execution Log records that Primary was contacted READ-ONLY only, states that **no INSERT, UPDATE, DELETE, DDL, GRANT, REVOKE or migration-apply call was issued to it**, and records Secondary `brplkqmbzffpxqgkkdzo` as never contacted.
- [x] No file under `supabase/` was created, modified or deleted, and no migration was authored or applied.
- [x] `pwsh -NoProfile -File scripts/check_repository_consistency.ps1` reports `REPOSITORY CONSISTENCY: CLEAN`, with Check 19 green against the extended evidence record.
- [x] No file outside this contract's Write Scope was created, modified or deleted, and Batch 6 Slice 13 was not opened, drafted or begun.

## Execution Log

[Appended by the executing agent after each run against this Change Request, before
IMPLEMENT is considered complete, per synchronization as defined in `CR_LIFECYCLE.md` §8
— this file is always implicitly in scope for this section.
Append-only — never edit or delete a prior entry, including a Blocked or Failed one.]

### 2026-09-20 — Steps 1-5, 7 and 8 executed. Step 6 follows in its own entry.

**STEP 1 — the adapter.** `scripts/check_database_parity_evidence.ps1` created. It computes no hash and compares no surface: it invokes `scripts/check_primary_ledger.ps1` for the ledger portion and `scripts/check_database_parity.ps1` for the comparison, and exits with the engine's exit code unchanged. Its own failures exit 1; the engine's 0/1/2 pass through untouched. The header records the deadlock, the credential constraint that makes evidence the only honest class, the LIVE READ / RECORDED / LOCAL VALIDATION ownership split, and the `GUARD-1` residual it does not close.

**STEP 2 — the profile.** `Get-ProfileEvidence`'s `DATABASE` `Local` list now ends with the adapter instead of the bare `scripts/check_database_parity.ps1`, and its `Deferred` note now reads that the three values are read LIVE through `supabase-primary` at the execution boundary and RECORDED in the evidence file, and that the run validated that record and did **not** contact Primary. No other profile was touched.

**STEP 3 — the control suite.** The DATABASE fixture gains a stub for the adapter; assertions 101 and 103 are retargeted to the command the profile actually runs; and eight new cases were added. **A finding worth recording: assertion 103's MUST-ACCEPT passed before this contract only because the fixture stubs the parity script to `exit 0`.** That is why a profile defect this total stayed latent since `SPEC-189` — the suite proved a shape the real repository could not reach.

**STEP 4 — the evidence record, refreshed from a live READ-ONLY Primary read.** Project ref confirmed `vrvtsxexkiiiivlkdxzp` via `get_project_url` before reading. Ledger `219 / dd2427080e9cfb5e8d1d162bf818360f`; function surface `f791acdba3e91462b1625ab8a723db4d` over 298 functions, read with `check_database_parity.ps1`'s own Check L2/P2 expression; structural surface `0c77972ecf1b45096cda327943a45c00` over 3,029 objects, read with `scripts/parity_surface.sql` — the same file local runs, per `PAR-3`. `schema_version` 1 → 2, `repository_head` set to `f07e654`, which is an ancestor of HEAD. **No INSERT, UPDATE, DELETE, DDL, GRANT, REVOKE or migration-apply call was issued.** Secondary `brplkqmbzffpxqgkkdzo` was not contacted.

**STEP 5 — proof. Accepting case first:**

```
== PAR-6: Primary parity evidence -> parity engine ==
  ledger evidence validated by scripts/check_primary_ledger.ps1
  evidence names project vrvtsxexkiiiivlkdxzp, read 2026-09-20T17:07:48Z at commit f07e654…
  (evidence class: a RECORDED Primary reading, not a live one -- this script never contacts Primary)
DATABASE PARITY: CLEAN (local proven; primary ledger, functions and structure proven)
PRIMARY PARITY EVIDENCE: CLEAN            exit 0
```

**Nine refusals, each measured in this repository, each restored afterwards:**

| # | Mutation | Exit | Refused because |
| --- | --- | --- | --- |
| N1 | evidence file absent | **1** | `MISSING … Primary parity is UNKNOWN, and UNKNOWN IS NOT CLEAN` |
| N2 | `project_ref` = Secondary | **1** | `WRONG PROJECT: evidence was read from 'brplkqmbzffpxqgkkdzo'` — refused by IDENTITY, not by hoping hashes differ |
| N3 | `function_surface_hash` removed | **1** | `INCOMPLETE … the Primary function-surface hash is UNPROVEN` |
| N4 | `structural_surface_hash` = `NOTAHASH` | **1** | `MALFORMED … not a 32-character lowercase md5` |
| N5 | `ledger_fingerprint` hand-edited | **1** | the ledger authority refused; adapter reports `not usable` |
| N6 | one ledger entry dropped | **1** | `THE REPOSITORY HAS 1 MIGRATION(S) PRIMARY HAS NOT RUN` — the pre-deploy shape |
| N7 | `repository_head` not an ancestor | **1** | the ledger authority refused |
| N8 | recorded function hash wrong | **1** | `PRIMARY FUNCTION DRIFT` from the engine |
| N9 | recorded structural hash wrong | **1** | `PRIMARY STRUCTURE DRIFT` from the engine |

N1–N4 are the adapter's own admissibility rules, N5–N7 are the composed ledger authority, N8–N9 are the engine. No refusal is credited to an unrelated guard. After the matrix the evidence file was verified **byte-identical** to its pre-mutation state and the accepting case re-measured **exit 0**.

**Semantic freshness, proven causally rather than by a clock.** One existing migration was extended with a trivial function — so every ledger identity stayed the same and `check_primary_ledger.ps1` still passed — and the database was rebuilt with `npx supabase db reset`. Local moved to **299 functions / `ea7e69afa344dcef2b7252cf4769a1a1`** and **3,030 objects / `b830fa5e13004289b1fb18ab90781154`**, and the still-correct recorded Primary values were reported as `PRIMARY FUNCTION DRIFT` and `PRIMARY STRUCTURE DRIFT`, **exit 1**. The migration was restored, the database reset again, and the accepting case re-measured **exit 0**. **This is also the measurement that refutes collapsing ledger parity into structural parity:** the ledger guard alone saw nothing, because identities never changed.

**STEP 7 — documentation and the register.** `ENGINEERING_METHOD.md §4` now states that the three values are read live at the execution boundary **and recorded**, that a deploying contract therefore carries the evidence file in its Write Scope, and that `-Finish` validates that record and runs the one parity engine against it — parity mandatory, fail-closed, with only the source of the values moved. It does **not** say Primary need not be read. `MASTER_GAP_REGISTER.md` marks `PAR-6` ✅ with the reproduction, the refuted alternatives and the residual, preserves the original finding below it, and carries a new dated freshness entry with the previous demoted to `Previously:`. `PAR-5` stays ✅; `PAR-7`, `USR-3` and `USR-4` stay 📋 and otherwise unchanged.

**STEP 8 — ai-map.** Already Applied: the manifest has not changed since the `Approve` commit regenerated it, and Check 7 compares the three `live_state` values and is green.

**Verification at this point.** `REPOSITORY CONSISTENCY: CLEAN` exit 0 with Check 19 green against the extended record; `git diff --check` exit 0; `test_agent_continuity.ps1` **278 passed, 0 failed**; `test_cold_start_state_guard.ps1`, `test_status_contradiction_guard.ps1`, `test_primary_ledger_guard.ps1` and `test_future_date_guard.ps1` all exit 0. `test_primary_ledger_guard.ps1` matters specifically: it mutation-tests the ledger validator, which this contract leaves byte-unchanged, and it still passes against the extended `schema_version` 2 record — proving the extension is additive and Check 19 keeps working in CI without Docker.

### 2026-09-20 — Step 6. The DATABASE lifecycle reaches certification with the repair in place.

The same disposable probe shape that reproduced `PAR-6` was re-run, driven by the repaired `check_agent_continuity.ps1` against a probe tree based on `f07e654` carrying the adapter and the extended evidence record under the probe's own Write Scope:

```
PASS: npx supabase db reset
PASS: npx supabase test db
PASS: pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1
PASS: npx supabase test db
PASS: Get-Content -Raw scripts/verify_database.sql | docker exec -i supabase_db_ORVION psql …
PASS: pwsh -NoProfile -File scripts/check_database_parity_evidence.ps1
PASS: pwsh -NoProfile -File scripts/check_repository_consistency.ps1
PASS: git diff --check
PASS: pwsh -NoProfile -File scripts/check_primary_ledger.ps1
EVIDENCE: DATABASE EXTERNAL: the three Primary values are read LIVE through supabase-primary at the
  DATABASE execution boundary and RECORDED in reports/evidence/primary-ledger-evidence.json; this run
  validated that record and did NOT contact Primary
LOCAL_CERTIFY: READY                                                                     exit 0
```

**Before the repair the identical shape ended `MANDATORY_VERIFICATION_FAILED` on the bare parity command with no receipt.** The verification list is otherwise unchanged — same reset, same two pgTAP passes, same HTTP suite, same smoke test — and the parity step is still there, still mandatory, still judged by `check_database_parity.ps1`. Only the source of its three values moved. The deferred note is printed by the profile itself, so the run states in its own output that it did not contact Primary.

**Deployment boundary, per the same mechanism and without a second one.** The pre-deploy state is already refused by the composed ledger authority: negative case N6 above, a repository holding one migration the recorded Primary ledger does not, reports `THE REPOSITORY HAS 1 MIGRATION(S) PRIMARY HAS NOT RUN` and exits 1. So a deploying contract cannot certify before it deploys; it must deploy, re-read Primary READ-ONLY, refresh this record, and then Finish — which is why `ENGINEERING_METHOD.md §4` now states that such a contract carries the evidence file in its Write Scope. One record cannot satisfy both sides of a deployment, and it is not asked to.

**Two guard refusals encountered while staging this probe, both correct and both recorded rather than worked around.** An earlier attempt overlaid the adapter and the evidence file as UNCOMMITTED changes and was refused `OUT_OF_SCOPE_WRITE` — the active contract had not authorised those paths — so the probe was rebuilt with them in its Write Scope and committed under its authority. An attempt to label the probe `SPEC-209` was refused `SPEC_ID_NOT_NEXT:208:209`, because the allocator hands out exactly the next free identity and the probe's base is `f07e654`. The probe therefore carries `208` on a branch that is never published and is deleted afterwards; reservation is anchored to the ref being validated and never `--all`, so the published `SPEC-208` on `main` is unaffected. Neither refusal changed the design.

**Primary and Secondary for this contract.** Primary `vrvtsxexkiiiivlkdxzp` was contacted READ-ONLY: `get_project_url`, and `select` statements over `supabase_migrations.schema_migrations`, `pg_proc`, and the surfaces defined by `scripts/parity_surface.sql`. **No INSERT, UPDATE, DELETE, DDL, GRANT, REVOKE or migration-apply call was issued**, and Primary's ledger is unchanged at 219 / `dd2427080e9cfb5e8d1d162bf818360f`. Secondary `brplkqmbzffpxqgkkdzo` was **never contacted**. No file under `supabase/` was created, modified or deleted in this contract, and no migration was authored. **Batch 6 Slice 13 was not opened, drafted or begun.**

## Verification Notes

[Appended by the reviewing agent after independently re-checking the Execution Log
against the live repository state. Append-only — never edit or delete a prior entry.]

---

### 2026-09-20 — executing agent, autonomous completion (`CR_LIFECYCLE.md` §5)

Verdict: Confirmed Complete

Findings: Re-checked against live state, not against the log. **Scope:** `git diff --name-status origin/main..HEAD` returns exactly nine paths, every one inside Write Scope, and **zero** under `supabase/`. **The one-authority claim was verified rather than trusted:** `scripts/check_database_parity.ps1`, `scripts/parity_surface.sql`, `scripts/check_primary_ledger.ps1`, `scripts/test_primary_ledger_guard.ps1` and `scripts/check_repository_consistency.ps1` are all **byte-identical to the baseline** — the comparison engine, the structural definition, the ledger authority and its mutation suite were composed, never edited. **Profile:** `Get-ProfileEvidence`'s DATABASE arm names `scripts/check_database_parity_evidence.ps1` and no longer names the bare command; the bare command appears nowhere as a verification this repository must pass. **Premature-completion check:** `Last Completed` and `Next capability` were compared line-for-line against `origin/main` and are **identical**, so no Implementation Step moved them. **Certification:** `-Finish` returned `LOCAL_CERTIFY: READY` with all nine verifications PASS, including `check_database_parity_evidence.ps1` as Additional Verification — so this contract's own Finish exercised the repair it ships. **Behaviour:** the decisive before/after stands — the same disposable DATABASE probe shape ended `MANDATORY_VERIFICATION_FAILED` with no receipt before the repair and reaches `LOCAL_CERTIFY: READY` after it, with the verification list otherwise unchanged and parity still mandatory, still fail-closed, still judged by the unchanged engine. **Evidence class:** the adapter's accepting output states it never contacted Primary, the profile's deferred note says the same, and `GUARD-1`'s residual is restated rather than dropped. **Register:** `PAR-6` ✅; `PAR-5` ✅; `PAR-7`, `USR-3`, `USR-4` still 📋 and otherwise unchanged. **Batch 6 Slice 13 was not opened, drafted or begun** — no contract file matching it exists.

Recommendation to human: Set Status to Complete

## Review Gate

[Completed by whoever performs the Review — the executing agent under autonomous completion
(`CR_LIFECYCLE.md` §5), otherwise a human. Do not mark Status as Complete until every item below
is checked.]

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as
      Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created, or deleted.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's
      Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.
