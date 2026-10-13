# Change Request — SPEC-273

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Make the publication range Gate admit exactly what each contract in a multi-contract range authorised, so the locally certified SPEC-271 → SPEC-272 history publishes for legitimate reasons and no pre-governor write can be laundered.

## Business Reason

SPEC-272 is Complete and locally certified (`LOCAL_CERTIFY: READY` at `4343b15`), but `scripts/publish_candidate.ps1` refuses `5a32f5b..3ddd5db` with `OUT_OF_SCOPE_WRITE: changes/SPEC-271-…`. Commit by commit, every mutation in that range lies inside its own governor's frozen Write Scope: SPEC-271 for commits 1–6 (Draft through Cancelled), SPEC-272 for commits 7–11 (Draft through Complete). The refusal arises because segments split only at Complete. The cancelled contract's commits are therefore judged by SPEC-272's scope, and SPEC-272 is terminal and cannot be widened.

Investigating that refusal reproduced the opposite defect, which is worse. Once a range holds a second completed segment, a write committed before a segment's governor first appears is judged by nothing. Case SC-2 exits 0 on the unchanged Gate, while the same history with one segment is refused.

The owner authorised drafting on 2026-10-13. Until this is resolved, eleven certified commits cannot reach `main`.

## Risks

This changes a governance rule, and that is the main risk. SPEC-171 established that an abandoned contract confers no write authority on a publication range. This contract keeps that rule where a cancellation and a completion close in the same commit (cases 129 and 133 are unchanged). Where a cancellation is committed on its own, it instead lets the cancelled contract's own approved scope authorise its own earlier commits. That authority applies only when a later completed contract names it in `Supersedes / Depends On`. A defect in the new segment logic could admit or refuse a range wrongly; cases SC-1 to SC-9, three mutation kills and the full control suite address that. Tightening the per-segment rule could refuse an unusual but legitimate multi-contract history in future. Before approval, the full existing control suite was run against the prototype in a disposable clone, and the result is recorded in Notes. The contract makes no database or Primary write and touches no product behaviour.

## Supersedes / Depends On

Depends on `changes/SPEC-272-the-pinned-cli-keeps-the-certified-local-stack.md` (Complete, unpublished), which supersedes `changes/SPEC-271-upgrade-project-local-supabase-cli-to-2-120-0.md` (Cancelled, unpublished). Neither file is modified.

## Write Scope

- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `CR_LIFECYCLE.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-271-upgrade-project-local-supabase-cli-to-2-120-0.md`
- `changes/SPEC-272-the-pinned-cli-keeps-the-certified-local-stack.md`
- `changes/TEMPLATE.md`
- `scripts/publish_candidate.ps1`
- `scripts/check_repository_consistency.ps1`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/migration-ci.yml`
- `supabase/config.toml`
- `package.json`
- `package-lock.json`

## Required Reading

- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md` §§1–4
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `changes/SPEC-242-segmented-publication-certification.md`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github

## Additional Verification

- `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Gate -BaseRef 5a32f5bee3243c71e2d29e77b3b8ef3ba2d93cec -HeadRef 3ddd5db83d1dc5dfc74ea5f6509d9ea955ef091c`

## Pre-Approval Evidence

Change Class: Owner-Decision

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A cancellation committed on its own (no completion in the same commit) now closes its own publication segment | `Get-PublicationSegments`, `Validate-PublicationSegments`, `Resolve-Contract` (multi-segment returns the last segment's governor), `publish_candidate.ps1` and the ORVION Acceptance range step (both call `-Gate -BaseRef`) | WRITE | The ranges these consumers receive are unchanged; only the segmentation they read changes. A cancelled segment can never be last, because a trailing one has no later carrier and is refused (SC-7). So `Resolve-Contract` still returns a completed governor. Prototype on the real range `5a32f5b..3ddd5db`: the unchanged Gate refuses (`OUT_OF_SCOPE_WRITE`), the prototype returns `READY / VERIFY / SPEC-272`. |
| A cancellation and a completion in the same commit (SPEC-171) | Cases 126–133 and SEG-18 | VERIFY | Such a commit closes one Complete and is still a single Complete segment, exactly as before. The full existing control suite was run against the prototype before approval (Notes). |
| Every range or segment's NET diff obeys its governor's frozen Write Scope, inside `Validate-CommittedRange` | Every multi-segment range; single-segment ranges (which already get the endpoint check); SEG-1 to SEG-18 and SEG-M1 to SEG-M3 | WRITE | The same endpoint rule single-segment ranges already apply (the `PublicationSegments.Count-le1` branch), reusing `Diff-Records` under the per-segment `BaseRef`/`HeadRef`, keyed on the same `$governing` and frozen baseline as the per-commit walk. That keying matters: an earlier prototype put the check in `Validate-PublicationSegments`, and SEG-M2 then failed because its single-point mutant no longer reached the second guard. With the check keyed on the walk's own parameter, SEG-M2's mutant moves both together and the existing test is unchanged. Already-published ranges are never re-judged. |
| A cancelled governor's write authority, judged at each commit: a commit at which it was still a Draft may change only that contract (`PRE_APPROVAL_WRITE`) | Cancelled segments and cancelled single-contract ranges; case 191h (`KrToggle`) and every other fixture that commits during Draft | WRITE | This applies `CR_LIFECYCLE.md`'s existing SPEC-163 rule (only Approved and In Progress carry write authority) exactly where a carrying successor could otherwise legalise a write. Probe P1: the first prototype published a carried cancelled contract's Draft-phase write (exit 0); it is now refused. A version that applied the rule to every contract failed case 191h, whose fixture writes `CR_LIFECYCLE.md` during Draft. That general gap (probe P1b, the unchanged Gate admitting a completed contract's Draft-phase write) is pre-existing, so it is registered as CTRL-16 (OPEN) rather than closed by changing an existing test. In the real history, every Draft commit (`1975890`, `303bb9c`, `e62085f`) changes only its own contract. No new policy. |
| Carry declaration | `Supersedes / Depends On` of a later completed governor | VERIFY | It is an existing frozen section that `changes/TEMPLATE.md` already requires for supersession. SPEC-272 names SPEC-271 there. No new contract field is added. |
| Lifecycle rule text | `CR_LIFECYCLE.md` (the lifecycle authority, per `ENGINEERING_METHOD.md` "a lifecycle rule to `CR_LIFECYCLE.md`") | WRITE | One paragraph after the SPEC-167 range-walk rule. The three enforcement markers are unchanged (staged copy checked: 3 of 3). |
| Finding record | `reports/master/MASTER_GAP_REGISTER.md` | WRITE | New CTRL-15 row (fixed), CTRL-16 row (OPEN) and dated header, following the SPEC-263 / CTRL-8 precedent. |
| Open-obligation classification | `reports/master/MASTER_EXECUTION_PLAN.md` Action registry; consistency Check 29 (CTRL-9, "nothing open is lost") | WRITE | Check 29 requires every open register member to be classified "in the same change that registered it". The rehearsal of the first Draft failed exactly there (`REGISTRY UNCLASSIFIED: CTRL-16`). One registry row: CTRL-16, VERIFIED DEFECT, engineering, `GATE-EVAL` (the same boundary as control-plane residual CTRL-11), plus the file's dated header. |
| Manifest active pointer | Boot, Check 7, `scripts/generate-ai-map.ps1` | WRITE | `ai-map.json` and `repository-index.md` are in Write Scope. |
| Unpublished SPEC-271 and SPEC-272 history | The publication of this contract's own range | VERIFY | Additional Verification re-judges `5a32f5b..3ddd5db` with the new Gate inside `-Finish`. Neither contract file is touched (Out of Scope), and terminal immutability still refuses any edit to them (SC-8). |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Working tree is clean and the branch is not behind its upstream | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| The five implementation files equal their pinned target hashes and no other tracked path changed | BEFORE_COMPLETION | 1 | 2 | 3 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `Validate-PublicationSegments` already runs `Validate-CommittedRange` per segment, and the single-segment branch already applies the net-diff endpoint scope rule. `Diff-Records` already reads the per-segment `BaseRef`/`HeadRef`, `Supersedes / Depends On` is an existing frozen section, and `MutationKillRangeAt` / `Pop` are the existing mutation and population machinery. Nothing new is invented; the existing rule now also applies per segment, and the existing supersession declaration is read.

Added Property: A multi-contract publication admits exactly what each contract authorised. It is judged segment by segment, including commits made before a segment's governor first appeared, and a cancelled contract's writes are judged by its status at the commit that made each one. A cancellation is carried only by an explicit, frozen declaration of a completed successor, and that declaration never legalises a Draft-phase or post-cancellation write.

Causal Negative: Already reproduced, 2026-10-13, with the unchanged Gate in an isolated sandbox built by the suite's own bootstrap. SC-1 (a pre-governor write, one segment) was refused with `OUT_OF_SCOPE_WRITE`. SC-2 (the same history plus one more completed segment) exited 0 (`MODE: VERIFY`), so the write was laundered. On the real repository, the unchanged Gate refuses `5a32f5b..3ddd5db` although every commit there is authorised by its own governor.

Positive Test Design: SC-3, a cancellation that the completed successor declares in Supersedes, is admitted. SC-9, two clean born-and-completed segments, is admitted. Every existing SEG, 126–133 and RANGE case keeps its verdict. Additional Verification admits the real range `5a32f5b..3ddd5db`.

Negative Test Design: SC-1 and SC-2 refuse `OUT_OF_SCOPE_WRITE:outside.txt`. SC-4 (undeclared) and SC-7 (trailing) refuse `CANCELLED_SEGMENT_NOT_CARRIED`. SC-5 (a carried cancelled contract writing outside its own scope) refuses `OUT_OF_SCOPE_WRITE:secret.txt`. SC-6 (a write before a carried cancelled contract appears) refuses `OUT_OF_SCOPE_WRITE:rogue.txt`. SC-8 (a carrier editing the terminal cancelled contract) refuses `HISTORICAL_CR_MUTATION`. SC-10 (a carried cancelled contract's Draft-phase write) refuses `PRE_APPROVAL_WRITE`. SC-11 (a write after cancellation, before the successor appears) and SC-12 (a successor writing inside the cancelled contract's scope) refuse `OUT_OF_SCOPE_WRITE:outside.txt`.

Non-Empty Population Obligation: The new family `SEG-CARRY` must record a non-zero accept population (SC-3, SC-9), reject population (SC-1, SC-2, SC-4 to SC-8, SC-10 to SC-12) and mutation population (four kills). It is added to the existing `NON-EMPTY POPULATION` assertion list.

Mutation Obligation: Each of the four load-bearing predicates is killed independently by `MutationKillRangeAt`: the net-diff loop, the carry refusal, the standalone-cancellation boundary, and the cancelled contract's Draft-phase write refusal. Prototype measurement: disabling the net diff turned SC-2 and SC-6 green, disabling the carry turned SC-4 green, and disabling the boundary turned SC-3 red. Two further candidate predicates (a trailing-cancellation throw and a cancellation-transition check) survived every case and were removed as dead code before drafting.

Post-Implementation Proof Obligation: The certified `-Finish` runs the full CONTROL profile, including `scripts/test_agent_continuity.ps1` with SC-1 to SC-12, the four SC mutation kills and the SEG-CARRY population, plus the Additional Verification over the real range. After `Complete`, `publish_candidate.ps1` must admit `origin/main..HEAD`, ORVION Acceptance must pass on the candidate, and `-Certify` must report READY on `main`.

## Implementation Steps

1. For each of the five files below, read its blob with `git hash-object --path=<path> <path>`. If it equals the `to` hash, record Already Applied. If it equals the `from` hash, replace the file with the reviewed content summarised in Notes, so that its blob becomes exactly the `to` hash. Any other value means stop and report; do not guess.
   - `scripts/check_agent_continuity.ps1`: from `09935cd60eea177eb5406d1f52139e44d86a9732` to `65fa3765344c30b6aeec52f24b1d05c9e096810f`
   - `scripts/test_agent_continuity.ps1`: from `b8763fb39863eb045d11f02c9fa6aa558d443696` to `65b6ff93d6712cf82a1bf2ec06dbd3a9a846e966`
   - `CR_LIFECYCLE.md`: from `433e05ba5767f0b20bf13298c6879c1ea5d05e98` to `b119aafea5007e16757822eeff091756a95469cb`
   - `reports/master/MASTER_GAP_REGISTER.md`: from `fea4fac05675fb54e565c0d06eb0f57fc8153d8d` to `503721130a10ce3bffe4d563943126ded8838787`
   - `reports/master/MASTER_EXECUTION_PLAN.md`: from `84c498db6117522b3af5f9327daa912f37260ee8` to `52424c50321b620c29a3960d6d33b0499b671f0e`
2. Check whether `git diff --name-only` against the approval commit lists only the five files above plus this contract. If so, record Already Applied. Otherwise stop and report any other path. Nothing else is edited in this step; the lifecycle commits own the manifest, `ai-map.json` and `repository-index.md`.
3. Check whether the Runtime Checkpoint already reads `Resume Step: DONE`. If so, record Already Applied. Otherwise synchronize the Execution Log and the Runtime Checkpoint to `DONE`, and commit the implementation and checkpoint together.
   - Run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` normally. No container or Docker state is changed for it.
   - If a test fails, preserve its exit code and evidence, and follow bounded recovery without weakening any assertion.

## Acceptance Criteria

- [x] `scripts/check_agent_continuity.ps1`, `scripts/test_agent_continuity.ps1`, `CR_LIFECYCLE.md`, `reports/master/MASTER_GAP_REGISTER.md` and `reports/master/MASTER_EXECUTION_PLAN.md` each have exactly their Step 1 `to` blob.
- [x] `scripts/test_agent_continuity.ps1` contains cases SC-1 to SC-12 and the four `SC-MUTATION` kills, and lists `SEG-CARRY` in the non-empty population families.
- [x] `changes/SPEC-271-upgrade-project-local-supabase-cli-to-2-120-0.md` and `changes/SPEC-272-the-pinned-cli-keeps-the-certified-local-stack.md` are byte-identical to `3ddd5db`.
- [x] The tracked implementation diff touches only this contract's Write Scope.

## Execution Log

### 2026-10-13 — Claude

Outcome: Complete

Step results:
- Step 1: Applied. Each file was at its `from` hash and was replaced with the reviewed content; `git hash-object --path` then read exactly its `to` hash:
  - `scripts/check_agent_continuity.ps1`: `09935cd6` to `65fa3765`
  - `scripts/test_agent_continuity.ps1`: `b8763fb3` to `65b6ff93`
  - `CR_LIFECYCLE.md`: `433e05ba` to `b119aafe`
  - `reports/master/MASTER_GAP_REGISTER.md`: `fea4fac0` to `50372113`
  - `reports/master/MASTER_EXECUTION_PLAN.md`: `84c498db` to `52424c50`
- Step 2: Applied. `git diff --name-only HEAD` listed exactly those five files; no other path changed.
- Step 3: Applied. The Runtime Checkpoint is synchronized to `DONE` and committed with the implementation. `-Finish` runs next, normally, with the ORVION containers running and no Docker state changed.

Commits: the implementation and checkpoint commit that carries this entry.

## Verification Notes

### 2026-10-13 — Claude (Independent Review of `9cd97af`)

Verdict: Confirmed Complete

Findings: re-checked against the committed repository after `-Finish`, not against the Execution Log.

1. **Criterion 1.** At HEAD the five files read exactly their pinned blobs: `65fa3765`, `65b6ff93`, `b119aafe`, `50372113` and `52424c50`.
2. **Criterion 2.** `scripts/test_agent_continuity.ps1` contains SC-1 to SC-12 (12 of 12), four `SC-MUTATION` kills (4 of 4), and `SEG-CARRY` in the non-empty population list.
3. **Criterion 3.** `git diff --quiet 3ddd5db HEAD` is clean for both `changes/SPEC-271-…` and `changes/SPEC-272-…`.
4. **Criterion 4.** `git diff --name-only 3ddd5db HEAD` lists exactly the five implementation files, the manifest, `ai-map.json` and this contract, all inside Write Scope. `repository-index.md` is in scope and reproduces unchanged.
5. **Local certification.** `-Finish` at `9cd97af` ran normally, with the ORVION containers up and no Docker change. Every command passed: `test_agent_continuity.ps1` (the full suite, including SC-1 to SC-12, the four kills, SEG-M1 to SEG-M3, 126–133 and 191h), `test_cold_start_state_guard.ps1`, `test_status_contradiction_guard.ps1`, `test_primary_ledger_guard.ps1`, `test_future_date_guard.ps1`, `check_repository_consistency.ps1`, `git diff --check`, and the Additional Verification `-Gate -BaseRef 5a32f5b -HeadRef 3ddd5db` over the real SPEC-271/272 history. `LOCAL_CERTIFY: READY`, 31.3 min, `concurrent_end=0`. The receipt names SPEC-273, READY, profiles CONTROL and REPOSITORY.
6. **Original defect against corrected behaviour.** The unchanged Gate refused the legitimately authorised `5a32f5b..3ddd5db` and admitted a pre-governor write laundered by a second completed segment (SC-2 exited 0). The repaired Gate admits the real range and refuses SC-2, plus every pre-approval, post-cancellation, out-of-scope, uncarried and terminal-edit write (SC-1, SC-4 to SC-8, SC-10 to SC-12).
7. **Authority.** The owner approved the bounded SPEC-171 amendment on 2026-10-13. No other architectural decision is introduced, and CTRL-16 is registered OPEN and classified rather than decided here.

Recommendation to human: Set Status to Complete (performed by the executing agent under the owner's 2026-10-13 Gate 2 authorization).

## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created, or deleted.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

- **Owner decision this contract asks for.** SPEC-171 (cases 129 and 133) holds that an abandoned contract confers no write authority on a publication range. This contract keeps that rule for a cancellation committed together with a completion. For a cancellation committed on its own, it adopts a new rule: the cancelled contract's own approved, frozen Write Scope authorises its own earlier commits, admitted only when a later completed contract names it in `Supersedes / Depends On`. This amends a recorded governance rule, so it needs explicit owner approval. Without it, SPEC-271 → SPEC-272 can reach `main` only by rewriting unpublished history, and the owner has forbidden that.
- **Per-commit audit of the unpublished range** (`5a32f5b..3ddd5db`, 11 commits). Each is checked against the manifest's active pointer and its governor's frozen scope at the parent commit.
  - `1975890` and `303bb9c`: SPEC-271 Draft; the contract only.
  - `7718f01`: Approve; manifest, `ai-map.json`, contract.
  - `4ad937f`: Begin; contract.
  - `5467328`: Pin; `package.json`, `package-lock.json` and the contract, all in SPEC-271's scope.
  - `3c93c1c`: Cancel; manifest, `ai-map.json`, contract.
  - `e62085f`: SPEC-272 Draft.
  - `db4e0a2`: Approve.
  - `f73991f`: Begin.
  - `4343b15`: Implement; `config.toml` and `migration-ci.yml`, both in SPEC-272's scope.
  - `3ddd5db`: Complete.

  No commit writes outside its own governor's scope.
- **Validator change (`scripts/check_agent_continuity.ps1`, +36/−4).**
  - `Get-PublicationSegments` also collects `Cancelled` transitions. A commit that closes exactly one Complete still closes a Complete segment; a commit that closes no Complete and exactly one Cancelled closes a cancelled segment.
  - In `Validate-PublicationSegments`, a cancelled segment must be named in a later completed governor's `Supersedes / Depends On`, otherwise `CANCELLED_SEGMENT_NOT_CARRIED`. A completed segment keeps its `INVALID_COMPLETION_TRANSITION` check.
  - `Validate-CommittedRange` reads the governor's status at the range or segment end. When it is `Cancelled`, a commit at which that contract was still a `Draft` may change only the contract (or a renamed former name), otherwise `PRE_APPROVAL_WRITE:<path>@<commit>`.
  - At the end of `Validate-CommittedRange`, when the governor's frozen baseline exists, every path in `Diff-Records` for the range or segment must be the governor's own file (or a renamed former name), or be in that frozen Write Scope; otherwise `OUT_OF_SCOPE_WRITE:<path>`.
- **Suite change (`scripts/test_agent_continuity.ps1`, +72/−1).** A `SEGMENT CARRY AND PER-SEGMENT SCOPE (SPEC-273)` block, placed just before the SEGMENTED PUBLICATION cases, adds SC-1 to SC-12 and four `MutationKillRangeAt` kills in family `SEG-CARRY`, and appends `SEG-CARRY` to the population list. The builders return a base SHA and never push, so a mutant commit stays below the judged range. The placement is deliberate: SEG-18 pushes a SPEC-902 contract into the sandbox origin, and a first run with the block after it failed `SPEC_ID_ALREADY_USED:SPEC-902`, a fixture collision rather than a validator defect.
- **`CR_LIFECYCLE.md` (+2).** One paragraph, "A multi-contract publication admits exactly what each of its contracts authorised", placed after the SPEC-167 paragraph. It includes the cancelled-contract write-authority sentence and names CTRL-16.
- **`MASTER_EXECUTION_PLAN.md` (+4/−1).** A new "Last updated" header (the previous one becomes "Previously:") and the CTRL-16 Action registry row after CTRL-11.
- **`MASTER_GAP_REGISTER.md` (+5/−1).** A new "Last updated" header (the previous one becomes "Previously:"), the CTRL-15 row (fixed) and the CTRL-16 row (OPEN) after CTRL-14.
- **Pre-approval evidence**, gathered 2026-10-13 in disposable environments only; no tracked file was changed.
  - The prototype on the real range: unchanged Gate refuses, prototype `READY`.
  - SC-1 to SC-9 (as C1–C9) against both Gates: the unchanged Gate admits SC-2 and refuses SC-3; the prototype is correct on all nine.
  - Five mutants: three killed, two removed as dead code.
  - Full existing control suite against the first prototype (net diff in `Validate-PublicationSegments`): 424 passed, 1 failed. The failure, SEG-M2, is explained in the Consumer Closure row above, and the design was corrected rather than the test.
  - Probes P1 to P3 (requirement 4). P1: the first prototype published a carried cancelled contract's Draft-phase write (exit 0); it is now `PRE_APPROVAL_WRITE` (SC-10). P2 and P3 (writes after cancellation) are refused by both Gates (SC-11, SC-12). P1b: the unchanged Gate admits a completed contract's own Draft-phase write. Enforcing that generally failed case 191h, whose fixture commits during Draft, so it is CTRL-16 (OPEN), and no existing test is changed.
  - Real history in a pristine checkout (requirement 3). A fresh clone at `3ddd5db`: clean tree, manifest `None.`, no SPEC-273 file, historical validator in place. It was judged from outside with `-Root`, so nothing in the checkout changed. Historical validator: `OUT_OF_SCOPE_WRITE: changes/SPEC-271-…` (exit 1). Repaired validator (`65fa3765…`): `READY / VERIFY / SPEC-272 / Complete`, `REPOSITORY: clean` (exit 0). The checkout was clean afterwards.
  - Final full staged suite (validator `65fa3765…`, suite `65b6ff93…`, byte-identical to the files under test; ORVION containers running; no Docker change): `AGENT CONTROL TESTS: 442 passed, 0 failed`, exit 0, 20.9 min, `concurrent_end=0`. That includes 129, 133, 191h, SEG-1 to SEG-18, SEG-M1 to SEG-M3, SC-1 to SC-12, the four SC mutation kills and `NON-EMPTY POPULATION SEG-CARRY`. An earlier full run of this design reported 412 passed and 0 failed outside the SC block, whose failures were the SPEC-902 fixture collision now fixed by placement.
- **Alternatives rejected.**
  - Listing SPEC-271's paths in this contract's scope does not work: those commits sit in SPEC-272's segment, so they would pass only through the gap, which is exploitation.
  - Fixing the gap alone makes `5a32f5b..3ddd5db`, and therefore this contract's own range, permanently unpublishable.
  - Rewriting unpublished history is forbidden by the owner.
- **WSL2 / Sandbox.** The owner's separate Sandbox/Prototype directive is handled after this contract, through its own lifecycle if any tracked change is earned.
