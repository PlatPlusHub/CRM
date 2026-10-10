# Change Request — SPEC-256

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make the range Gate judge SPEC allocation with one authority, the per-commit walk against each commit's own parent, so an identity reserved inside an unpublished range and lawfully skipped is admitted. Decide allocation activation once from the original range base, so a range that removes the allocation marker still cannot suspend enforcement.

## Business Reason

- **The owner's decisions of 2026-10-10:** Option 1, a strictly bounded corrective control-plane contract. Then Design C, approved for proof and Draft preparation only.
- **The defect (CTRL-7).** SPEC-255 is Complete locally at `ef2e948`, but `-Gate -BaseRef origin/main` refuses its publication range with `SPEC_ID_NOT_NEXT:253:254`, and CI's ORVION Acceptance uses `origin/main` as its base. SPEC-252's Notes reserved SPEC-253 inside that unpublished range, so the allocator lawfully handed out SPEC-254 (`CR_LIFECYCLE.md` §4, `SPEC-163`). The hook and the per-commit walk accept that allocation. The endpoint call `Validate-SpecAllocation $records $base` judged the net range against `origin/main`'s reservations instead.
- **Not redundant.** That call was also the only guard for a range whose base is under enforcement and which removes the allocation marker, allocates while it is absent, and restores it. Removing the call alone admitted such a range, so this contract moves that protection into the per-commit walk instead of dropping it.

## Risks

- **Admission is unchanged except for the false refusal.** The only verdict that changes is that a lawfully skipped identity is now admitted. Every refusal the endpoint call supplied is now supplied by the per-commit walk at the allocating commit.
  - Shown on twenty-four allocation cases: 180 to 192, 191b and the new 191c to 191l.
  - Shown on thirteen allocation mutants: the eight existing ones kept and the five added here.
- **History is unaffected.** The allocation marker was added once (`fcf065a`) and never removed on `origin/main`, so no published range contains a commit whose parent lacks the marker while its base carries it. Only such a commit is newly judged.
- **Publication.** The intended publication is `origin/main..` this contract's Complete: SPEC-255's segment, then this contract's. It was proved READY in a disposable clone with the exact prototype bytes. See Notes.
- **No Primary access, migration or database test.**

## Supersedes / Depends On

None. It depends on SPEC-255, which is Complete locally at `ef2e948` and unpublished. This contract publishes after it, in the same push, as the second publication segment. SPEC-255 and the cancelled SPEC-251, SPEC-252 and SPEC-254 are not modified.

## Write Scope

- `changes/SPEC-256-range-allocation-is-judged-commit-by-commit-from-the-original-base.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `CR_LIFECYCLE.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-255-recorded-contract-text-is-compared-by-code-point-from-a-pinned-boundary.md`
- `changes/SPEC-254-recorded-contract-text-is-compared-by-code-point-from-a-pinned-boundary.md`
- `changes/SPEC-252-recorded-contract-text-is-compared-by-code-point-from-a-pinned-boundary.md`
- `changes/SPEC-251-recorded-contract-text-is-compared-by-code-point.md`
- `changes/TEMPLATE.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `scripts/check_repository_consistency.ps1`
- `scripts/publish_candidate.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/run_timed.ps1`
- `scripts/watch_run.ps1`
- `scripts/watch_ci.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `scripts/test_status_contradiction_guard.ps1`
- `scripts/test_primary_ledger_guard.ps1`
- `scripts/test_future_date_guard.ps1`
- `.github/workflows/agent-control.yml`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/migration-ci.yml`
- `AGENTS.md`
- `GOVERNANCE.md`
- `ENGINEERING_METHOD.md`
- `CODING_STANDARDS.md`
- `reports/evidence/primary-ledger-evidence.json`

## Required Reading

- `CR_LIFECYCLE.md` §4, especially the allocation-marker paragraph
- `scripts/check_agent_continuity.ps1`: `Allocation-ActiveAt`, `Allocation-Events`, `Get-SpecSequenceCursor`, `Get-SpecIdReservation`, `Validate-SpecAllocation`, `Validate-HistoryAndIds`, `Validate-CommittedRange`, `Get-PublicationSegments`, `Validate-PublicationSegments`, `Resolve-Contract` and the endpoint block
- `scripts/test_agent_continuity.ps1`: `MutationKillRange`, `MutationKillRangeAt`, `Pop`, cases 180 to 192 and 191b, the range-scoped mutations and the NON-EMPTY POPULATIONS loop

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github

## Additional Verification

- `pwsh -NoProfile -File scripts/readiness_population.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Range-mode allocation in `scripts/check_agent_continuity.ps1`: the net-diff `Validate-SpecAllocation` call is replaced by `$script:RangeAllocationActive`, decided once from the original base; the per-commit gate becomes base-or-parent | Every range Gate: ORVION Acceptance and Agent Control (`-Gate -BaseRef`), `publish_candidate.ps1`'s range proof, and each publication segment through `Validate-PublicationSegments` | WRITE | Non-comment tokens differ from `e40be2e7…` in those two statements only. On the prototype: 191c to 191l, the five new mutants and cases 180 to 192 and 191b pass; the real range `origin/main..ef2e948` reads READY instead of `SPEC_ID_NOT_NEXT:253:254`. |
| The local (hook) allocation call `Validate-SpecAllocation $records $base -CheckOrigination` and `Validate-HistoryAndIds` (collision, duplicate, terminal immutability) | The pre-commit hook; `-Finish`; Boot | VERIFY | Byte-unchanged. Cases 26, 27, 93, 180 to 190 and the K-local and K-reservation mutants keep their verdicts. |
| `scripts/test_agent_continuity.ps1`: cases 191c to 191l and five mutants. `K first-parent activation marker` is replaced, because its search string no longer exists. Two ORIGIN mutants (SPEC-202) are re-anchored on the repaired lines | ORVION Acceptance and Agent Control run the suite; `-Finish` (CONTROL) | WRITE | Prototype: 17/0 for the new cases and the range mutants; 15/0 for the ORIGIN block (cases 213 to 220 and its three mutants). A full suite on an earlier prototype read 386/2: the two failures were exactly these ORIGIN anchors (`applied=False`). |
| `CR_LIFECYCLE.md` §4, allocation-marker paragraph: one sentence | Authors; no parser reads this sentence | WRITE | The three marker lines are byte-unchanged; CTRL4-26 still reads the character marker's first declaration. |
| `MASTER_GAP_REGISTER.md`: a new CTRL-7 row, FIXED by this contract, and a dated `Last updated:` line (Check 21 requires it) | Checks 2, 11, 14, 21 and 25; `scripts/readiness_population.ps1` | WRITE | No other row changes. Prototype in the disposable clone: repository consistency CLEAN; readiness population exit 0. |
| The unpublished history `origin/main..ef2e948`: SPEC-251, SPEC-252 and SPEC-254 Cancelled, SPEC-255 Complete | The range Gate at publication, as segment 1 | VERIFY | Not modified. Disposable-clone proof: the full intended range reads READY with this contract as the final governor. |
| Manifest `Last Completed` and Active pointer; `ai-map.json` | Checks 5 and 7; Boot; `test_cold_start_state_guard.ps1` | WRITE | `Next capability` (Batch 6 Slice 35) and the open-decision line (MAIL-1, RET-1, PH8-10) are unchanged. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Repository consistency is CLEAN | BEFORE_COMPLETION | NONE | NONE | Step 3 |
| The CONTROL suites pass: agent continuity and the four guard self-tests | BEFORE_COMPLETION | NONE | NONE | Step 3 |
| Every derived readiness id is classified | BEFORE_COMPLETION | NONE | NONE | Step 3 |
| `ai-map.json` matches its generator | BEFORE_COMPLETION | NONE | NONE | Step 4 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism:
- The per-commit allocation walk in `Validate-CommittedRange`, which already judges each allocation against its own parent.
- `Allocation-ActiveAt` and the declared marker in `CR_LIFECYCLE.md`.
- The publication segments, which already run that walk for every segment.
- The suite's `MutationKillRange`, `MutationKillRangeAt`, `Pop` and NON-EMPTY POPULATIONS.

Nothing is added: no allocator, reservation source, ledger, allowlist, exception, mode, switch, file, workflow or capability. One authority replaces two.

Added Property: In range mode, a range whose original base carries the allocation marker judges every commit's allocation against that commit's own first parent, including commits whose parent lacks the marker and commits in any publication segment. A range whose base lacks the marker judges only commits whose parent carries it, as before. No allocation is judged against the range base's reservations.

Causal Negative:
- **The evaluator at `e40be2e7…`** (SPEC-255) refuses the real range `origin/main..ef2e948` with `SPEC_ID_NOT_NEXT:253:254`, and refuses the in-range-reservation case (191c) the same way.
- **Removing its endpoint call alone** admits the marker-removal range (191g) and the two-segment marker-removal range (191k), each with `ORVION: READY`. That is why the call is replaced, not deleted.

Positive Test Design: 191c, an identity reserved by tracked text inside the range, then skipped; 191f, two ordinary allocations in one range; 191h, 191j and 191l, the controls for 191g, 191i and 191k with the next identity; and the unchanged 181, 185, 187, 191b and 192.

Negative Test Design: 191d, the same skip with no reservation; 191e, an identity reserved and deleted inside the range, then taken; 191g, the marker removed, a jump allocated and the marker restored; 191i, the marker activated inside the range, then a jump; 191k, the same as 191g across two publication segments; and the unchanged 180, 182 to 184, 186, 188 to 191. Each new refusal must be `SPEC_ID_NOT_NEXT` or `SPEC_ID_HISTORICALLY_RESERVED` carrying the allocating commit's short SHA, which only the per-commit call raises.

Non-Empty Population Obligation: Family `K-range` gains 5 accepting cases, 5 refusing cases and 5 mutation kills, beside its existing members (191, 191b, and the per-commit invocation mutant), asserted by `NON-EMPTY POPULATION K-range`.

Mutation Obligation: Each mutant is applied to a committed sandbox copy by the suite's own harness, which asserts that the find string was present, that the pristine run shows the expected evidence and that the mutated run does not. A builder never resets the fixture, so the committed mutant is the evaluator that judges the range. A mutant whose application is not proven is a harness error, never a kill.

| Mutant | Change | Killed by |
| --- | --- | --- |
| M1 | the net-diff range allocation call restored | 191c's range (expected `ORVION: READY`) |
| M2 | the range-base term removed from the per-commit gate | 191g's range |
| M3 | the first-parent term removed from the per-commit gate | 191i's range |
| M4 | range-base activation never computed (`$false`) | 191g's range |
| M5 | activation read from the segment's substituted base | 191k's range |

The existing `K per-commit range invocation` mutant is kept and still killed by case 191's laundering range. `K first-parent activation marker` is replaced by M3, because its search string no longer exists. Two SPEC-202 ORIGIN mutants keep their intent on the new lines:
- forcing the per-commit gate on is killed by the pre-activation range;
- re-inserting an endpoint call that judges origination is killed by the born-and-completed lifecycle.

Post-Implementation Proof Obligation: On the final committed bytes:
- canonical `-Finish` (CONTROL and REPOSITORY: agent continuity with every case and mutant, the four guard self-tests, repository consistency and `scripts/readiness_population.ps1`);
- then `-Gate -BaseRef origin/main` over the whole range, including SPEC-251's, SPEC-252's, SPEC-254's and SPEC-255's commits, with two publication segments;
- then `publish_candidate.ps1`, candidate CI, exact-SHA promotion to `main`, `main` CI and `-Certify`.

## Implementation Steps

Every file is written LF. The "from" hashes are the committed bytes at `ef2e948`. The "to" hashes were measured on the prototype.

1. **Check** whether `scripts/check_agent_continuity.ps1` contains `$script:RangeAllocationActive=[bool]$BaseRef-and(Allocation-ActiveAt $BaseRef)`. If absent, write the evaluator and its suite exactly as prototyped:
   - `scripts/check_agent_continuity.ps1` from `e40be2e7e51b5a6bd0ce0181de9e69fb047bdaebcdc38f891c569d9a4540b369` to `dbfbf8a9ede8872b7d4026fdb7014d2307b5f2ba477328e229a3d5c2fd99e1da`
   - `scripts/test_agent_continuity.ps1` from `c2ce82d8d6b654418b8be1fc56e72332448fc47bd9753f173b0bf9d78e6b5d5c` to `057dc455a24140c71348dba9aa92893a3320c4c88eed769ca3e35e7f6fd2a808`

   If either holds bytes other than its "from" hash, or a resulting hash differs, stop.
2. **Check** whether `CR_LIFECYCLE.md` contains ``so removing it inside a range cannot suspend enforcement (`SPEC-256`)``. If absent, apply exactly as prototyped:
   - `CR_LIFECYCLE.md` from `6b70b792e1ab99e5597635d0ac2f4ec42bd9f15c0551f7ebdd3cf909606283d4` to `cdc316bb8c84a9ef57ffad793d8a5862fd13c2d58153e983f1121642778432b9`
   - `reports/master/MASTER_GAP_REGISTER.md` from `d50b600224030eef28d59cca2389c300ca52e157244e1c3048892fd8ba96690c` to `b9f1ddebe056af5ee997e8c5c7827d96dcaec5d93c1f6a029d2abfc78cb118f0`

   If either holds bytes other than its "from" hash, or a resulting hash differs, stop.
3. **Check** for a `Local certification` Execution Log entry. If absent:
   - commit steps 1 and 2 with an Execution Log entry;
   - commit the Runtime Checkpoint as `Resume Step: DONE`;
   - run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` once, alone, on the clean committed tree, and require `LOCAL_CERTIFY: READY`.

   No step runs any command that `-Finish` runs.
4. **Check** whether the manifest's `Last Completed` begins `**SPEC-256`. If not:
   - set it to this contract, with the Active pointer `None.`;
   - leave `Current Module`, `Next capability` (Batch 6 Slice 35) and the open-decision line unchanged;
   - keep the manifest within 7000 characters and 1200 per line;
   - regenerate `ai-map.json` with `scripts/generate-ai-map.ps1` and convert it to LF.

   Then Review, and Complete.

## Acceptance Criteria

- [ ] `scripts/check_agent_continuity.ps1` (`dbfbf8a9…`) decides range allocation activation once from the original base, judges each commit's allocation against its own first parent whenever that base or that parent carries the marker, and makes no net-diff allocation call in range mode; its local allocation call is unchanged.
- [ ] `scripts/test_agent_continuity.ps1` (`057dc455…`) carries cases 191c to 191l and mutants M1 to M5 in family `K-range`, no longer carries `K first-parent activation marker`, anchors the two ORIGIN mutants it re-targets on the repaired lines, and passes in `-Finish`.
- [ ] `CR_LIFECYCLE.md` (`cdc316bb…`) states that a range whose base carries the marker judges every commit even where an intermediate state lacks it, and its three marker lines are byte-unchanged.
- [ ] The register (`b9f1ddeb…`) records CTRL-7 fixed by this contract in a new row and a new dated `Last updated:` line, demoting the previous one to `Previously:`, and no other row changes.
- [ ] At Complete, the manifest names this contract, its `Next capability` is still Batch 6 Slice 35, its open-decision line is MAIL-1, RET-1 and PH8-10, and `ai-map.json` is regenerated LF.

## Execution Log

None.

## Verification Notes

None.

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

**Evidence before freezing.** Measured 2026-10-10 on `DESKTOP-0U3LC2V` (pwsh 7.6.6, 8 logical CPUs), in scratch sandboxes and a disposable clone. Nothing was pushed, and the repository was not modified.

- **Identity.** The allocator's own functions, run read-only at `ef2e948`, read the cursor as 255 and found this identity unreserved, with no tracked mention.
- **Root cause.** In range mode the per-commit walk always runs before READY:
  - publication segments cover every commit, and trailing work is refused;
  - a range with no governing contract throws `NO_GOVERNING_CR`.

  The endpoint call and the walk therefore differed only in two respects. First, they consulted different reservations: the base's against each parent's. Second, they activated differently: on the base's marker against each parent's.
- **Three-way discrimination** on the current evaluator, the endpoint call removed alone, and this design:
  - **The current evaluator** refuses 191c falsely.
  - **Removing the call alone** admits 191g and 191k.
  - **This design** refuses both with `SPEC_ID_NOT_NEXT` at the allocating commit, and accepts every control.
- **Prototype checks:**
  - New cases and range mutants: 17/0.
  - On evaluator bytes whose non-comment tokens are identical to the prototype's:
    - cases 180 to 192 and 191b: all pass;
    - the eight existing allocation mutants: all killed;
    - the segment-substitution mutant: killed.
  - The real range `origin/main..ef2e948`: READY, against `SPEC_ID_NOT_NEXT:253:254` on the current evaluator.
- **Two-segment publication proof, in a disposable clone of `ef2e948`.** The clone used `core.autocrlf=false` and the repository's own hooks, and was never pushed.
  - **Lifecycle.** This contract's whole lifecycle went through the real pre-commit Gate, and every step read `ORVION: READY`:
    - the Draft's read-only probe returned `APPROVAL_EVIDENCE: PASS`, and the Approve commit printed it;
    - Implement wrote the four prototype files byte for byte;
    - consistency read CLEAN and readiness exited 0 at the simulated DONE.
  - **First `-Finish`.** On an earlier prototype it read 386 passed and 2 failed. Both failures were ORIGIN mutants anchored on the removed line (`applied=False`); they are re-anchored here.
  - **Second `-Finish`.** On the final prototype bytes it returned `LOCAL_CERTIFY: READY` in 51.7 min, alone, with every stage `PASS`. The simulated Complete then passed the Gate, `STATUS: Complete`, with that genuine receipt.
  - **The range Gate** `-Gate -BaseRef ae1d130 -HeadRef` the simulated Complete covers 31 commits. It holds exactly two Complete transitions, SPEC-255 at `ef2e948` and this contract at the endpoint, with no trailing work:

    | Evaluator | Result |
    | --- | --- |
    | Repaired | `ORVION: READY`, `MODE: VERIFY`, `CR: SPEC-256` |
    | Current | `SPEC_ID_NOT_NEXT:253:254` on the same range |

  - **The Draft committed in the clone** differs from this one only in this bullet.
