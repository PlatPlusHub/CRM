# Change Request — SPEC-252

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make approved and recorded contract text resistant to invisible, case-only and Unicode-equivalence mutations, as SPEC-251 did, and make its forward-only activation boundary impossible to move or re-point: a boundary counts only if it lies in the history of the commit that declares it and equals the value first committed, and the repository's own value is pinned by a permanent test.

## Business Reason

- **The owner's decision (2026-10-09, Option B):** do not Complete or publish SPEC-251 with the demonstrated activation-marker bypass. Cancel it, preserve its commits and evidence, and draft a bounded successor that keeps its proven implementation and tests and adds only what closes the bypass.
- **The bypass, reproduced on SPEC-251's frozen evaluator (`21fa36ab…`).** A contract whose approved Write Scope names `CR_LIFECYCLE.md` could disable the character rule in CI's range mode in two ways, and the range Gate read `ORVION: READY` both times:
  - by pointing `Evidence Character Enforcement` at a commit on an unrelated branch and then adding a BEL;
  - by moving the marker forward past its own BEL.
- **What SPEC-251 already earned, and this contract keeps.** A PowerShell escape committed a NUL into SPEC-250 and a BEL into SPEC-239. On the evaluator at `ae1d130`, fourteen attacks on frozen or recorded text were admitted with `ORVION: READY`. SPEC-251's repair refused all of them and reached `LOCAL_CERTIFY: READY`; it was cancelled only for the boundary.

## Risks

- **A legitimate contract could be newly refused.** Measured not to happen: over the thirteen publication ranges `73e571c..ae1d130`, each head's own evaluator, the `ae1d130` evaluator and this evaluator all read `ORVION: READY` (Notes). The MUST-ACCEPT cases of SPEC-251 are kept unchanged.
- **The boundary reading is stricter, never looser.** A marker that is missing, malformed, unknown, outside the declaring history, or different from its first committed value yields no boundary, so the rule applies everywhere. The only exemption left is for a transition whose before-state predates the first-declared boundary.
- **History.** No contract is rewritten. SPEC-251 is Cancelled and preserved; its file is in this Write Scope only because its cancellation lies in this publication range. SPEC-239's BEL stays.
- **CONTROL text.** `CR_LIFECYCLE.md` gains one paragraph and one marker line after the CTRL-1 marker; the two existing marker lines stay byte-identical. `CODING_STANDARDS.md §12` gains one rule.
- **No Primary access, migration or database test.** No later SPEC identity is named.

## Supersedes / Depends On

Supersedes SPEC-251 (`changes/SPEC-251-recorded-contract-text-is-compared-by-code-point.md`), Cancelled at `78853c7` by human command before publication. SPEC-239 and SPEC-250 are Complete and are not modified.

## Write Scope

- `changes/SPEC-252-recorded-contract-text-is-compared-by-code-point-from-a-pinned-boundary.md`
- `changes/SPEC-251-recorded-contract-text-is-compared-by-code-point.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `CR_LIFECYCLE.md`
- `CODING_STANDARDS.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-239-issuance-holds-on-every-door.md`
- `changes/SPEC-250-a-subscription-transition-is-judged-on-the-row-it-replaces.md`
- `changes/TEMPLATE.md`
- `scripts/check_repository_consistency.ps1`
- `scripts/publish_candidate.ps1`
- `scripts/generate-ai-map.ps1`
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
- `reports/evidence/primary-ledger-evidence.json`

## Required Reading

- `changes/SPEC-251-recorded-contract-text-is-compared-by-code-point.md`, in full, including its cancellation entry
- `CR_LIFECYCLE.md` §4, §8 and the three declared-marker paragraphs; `CODING_STANDARDS.md §12`
- `scripts/check_agent_continuity.ps1`: `Normalize`, `EvidenceBody`, `Validate-FrozenAuthority`, `Validate-EvidenceAppendOnly`, `Validate-Checklist`, `Historical-Guard-IsActive`, `Get-CharacterBoundary`, `Character-Guard-IsActive`, `Validate-CommittedRange` and the endpoint block
- `scripts/test_agent_continuity.ps1`: `MutationKill`, `MutationKillRangeAt`, `Pop`, case 119i and the NON-EMPTY POPULATIONS loop
- `reports/master/MASTER_GAP_REGISTER.md` CTRL-3; `reports/master/MASTER_EXECUTION_PLAN.md`, the Pre-Production Readiness Closure gate

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
| Ordinal `Validate-FrozenAuthority`, `Validate-EvidenceAppendOnly` and `Validate-Checklist`, and `Validate-NoNewProhibitedCharacter` at the endpoint and per commit (carried from SPEC-251 unchanged) | Every Gate: the pre-commit hook, `-Finish`, Agent Control and ORVION Acceptance (`-Gate -BaseRef`); every governed contract | WRITE | CTRL4-1 to CTRL4-23 and SPEC-251's twelve still-meaningful mutants pass unchanged on the final bytes. `Normalize` and `EvidenceBody` are unchanged. |
| `Get-CharacterBoundary`: the declared value counts only if it is in the declaring commit's history and equals the value first committed in `CR_LIFECYCLE.md` | `Character-Guard-IsActive`, at the endpoint and per commit; any future contract that names `CR_LIFECYCLE.md` | WRITE | CTRL4-24 (moved forward), CTRL4-25 (re-pointed at an unrelated branch) and CTRL4-27 (first declared outside the history) refuse, judged the way CI judges a range, in a sandbox with no pre-commit hook. CTRL4-21 to CTRL4-23 keep their verdicts. |
| `Evidence Character Enforcement: ae1d130d82a1173099d858e667aab8dc88650d84` and its paragraph in `CR_LIFECYCLE.md` | The Gate; case CTRL4-26; the existing `SPEC Allocation Enforcement` and `Historical CR Immutability Enforcement` lines | WRITE | CTRL4-26 pins the repository's value. On real history, a marker moved forward or re-pointed and committed with the hook skipped turns CTRL4-26 red, and the evaluator then finds no boundary. The two existing marker lines are byte-unchanged. |
| `scripts/test_agent_continuity.ps1`: CTRL4-1 to CTRL4-27, fifteen CTRL-4 mutants, family `CTRL4` | ORVION Acceptance (runs the suite with `fetch-depth: 0`) and Agent Control on feature branches; `-Finish` (CONTROL) | WRITE | Final prototype: see Notes. CTRL4-26 needs the repository's history, which both workflows fetch. |
| Historical publication ranges on `origin/main` | Anyone replaying a published range | VERIFY | Thirteen ranges, three conditions, 39 verdicts, all `ORVION: READY` (Notes). |
| `CODING_STANDARDS.md §12`: one rule | Authors; no parser | WRITE | One bullet before the `$Matches` trap. |
| `MASTER_GAP_REGISTER.md`: CTRL-4 fixed; CTRL-5, CTRL-6, CI-2, TEST-4, PERF-2, OPS-3 and OPS-4 open | Checks 2, 11, 14, 21 and 25; `scripts/readiness_population.ps1`; the open-decision pin in `test_cold_start_state_guard.ps1` | WRITE | Owner Decision is `—` on every row. Prototype: repository consistency CLEAN; the four guard self-tests pass. |
| `MASTER_EXECUTION_PLAN.md`: the seven open ids join the gate's control-plane residuals by name only | `scripts/readiness_population.ps1`, which derives every status from the register | WRITE | The plan carries ids and no status; its own rule says the register wins. Prototype: every derived id named, exit 0. |
| SPEC-251's contract, Cancelled at `78853c7` | The range Gate (its cancellation lies in this publication range); Check 2 | VERIFY | Not modified by this contract; listed in Write Scope so the range's net diff is authorized. |
| Manifest `Last Completed` and Active pointer; `ai-map.json` | Checks 5 and 7; Boot; `test_cold_start_state_guard.ps1` | WRITE | `Next capability` (Batch 6 Slice 35) and the open-decision line (MAIL-1, RET-1, PH8-10) are unchanged. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Repository consistency is CLEAN | BEFORE_COMPLETION | NONE | NONE | Step 4 |
| The CONTROL suites pass: agent continuity and the four guard self-tests | BEFORE_COMPLETION | NONE | NONE | Step 4 |
| Every derived readiness id is classified | BEFORE_COMPLETION | NONE | NONE | Step 4 |
| `ai-map.json` matches its generator | BEFORE_COMPLETION | NONE | NONE | Step 5 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism:
- SPEC-251's evaluator and suite, carried forward.
- CTRL-1's declared-boundary pattern in `CR_LIFECYCLE.md`, read from the working tree through `$script:HistoricalAuthority`, and its repository pin, case 119i.
- Git ancestry (`merge-base --is-ancestor`) and the authority's own history (`log -G`), already used by the Gate.
- The suite's `MutationKill`, `MutationKillRangeAt`, `Pop` and NON-EMPTY POPULATIONS.

Nothing else is added: no mode, switch, file, workflow or capability. Rejected: reading the marker from the range base (it would make every historical replay retroactive); a hard-coded SHA in the evaluator (a second authority); refusing every edit of `CR_LIFECYCLE.md` (it is a legitimate control surface).

Added Property: The character rule exempts a transition only when its before-state predates a boundary that lies in the history of the declaring commit and equals the value first committed in `CR_LIFECYCLE.md`. Any other marker yields no boundary and the rule applies everywhere. In this repository that value is pinned to `ae1d130…`, the last commit published before the rule existed.

Causal Negative: On SPEC-251's evaluator (`21fa36ab…`), in the suite's sandbox with no pre-commit hook, a contract owning `CR_LIFECYCLE.md`:
- re-pointed the marker at a commit on an unrelated branch and added a BEL: `ORVION: READY`;
- added a BEL, then moved the marker forward past it: `ORVION: READY`.

An ordinary contract was refused `OUT_OF_SCOPE_WRITE:CR_LIFECYCLE.md`, and the local Gate refused the BEL. On real history SPEC-251 had no pin for this marker.

Positive Test Design: CTRL4-15 to CTRL4-21 (SPEC-251's MUST-ACCEPT cases) and CTRL4-26, the repository pin on real history. SPEC-251's existing cases pass unchanged.

Negative Test Design: CTRL4-1 to CTRL4-14, CTRL4-22 and CTRL4-23 (SPEC-251); CTRL4-24 marker moved forward past the BEL; CTRL4-25 marker re-pointed at an unrelated branch; CTRL4-27 first declaration outside the declaring history. Each of the three new cases is judged by `RunRange`, the CI invocation shape, in a sandbox that has no hook.

Non-Empty Population Obligation: Family `CTRL4` carries 8 accepting cases, 19 refusing cases and 15 mutation kills, asserted by `NON-EMPTY POPULATION CTRL4`. The replay population is every publication range between consecutive Complete commits from SPEC-237 to SPEC-250.

Mutation Obligation: Each mutant is applied to a committed sandbox copy by the suite's own harness, which asserts that the find string was present, that the pristine run shows the expected evidence and that the mutated run does not. A mutant whose application is not proven is a harness error, never a kill.

| Mutant | Change | Killed by |
| --- | --- | --- |
| M1 | frozen sections compared with `-ne` | Objective case edit |
| M2 | Out of Scope compared with `-ne` | Out of Scope case edit |
| M3 | evidence prefix by culture `StartsWith` | decomposed re-encoding |
| M4 | checklist wording compared with `-ne` | Acceptance case edit |
| M5 | endpoint character rule removed | a NUL entering |
| M6 | zero-width space dropped from the class | a zero-width space entering |
| M7 | history refused outright instead of counted | historical BEL with an append |
| M8 | a CRLF counted as a lone CR | CRLF working copy |
| M9 | a variation selector refused after a symbol | the emoji entry |
| M10 | per-commit character rule removed | a NUL added and removed in one range |
| M11 | per-commit rule ignores the boundary | a character added before the boundary |
| M12 | endpoint rule ignores the boundary | the same range |
| M13 | the declaring-history precondition removed | a first declaration on an unrelated branch (CTRL4-27) |
| M14 | the first-declaration check removed | the marker moved forward (CTRL4-24) |
| M15 | an unproven boundary reads inactive | the add-and-remove range with no marker |

SPEC-251's mutant `$ancestorCode-ne1` to `$ancestorCode-eq0` is retired as EQUIVALENT: an unknown or unrelated boundary is now refused by the precondition before that line runs. M13 and M14 replace it, each killed by the bypass it closes.

Post-Implementation Proof Obligation: On the final committed bytes, canonical `-Finish` (CONTROL and REPOSITORY: agent continuity with every CTRL-4 case and mutant including CTRL4-26 on real history, the four guard self-tests, repository consistency and `scripts/readiness_population.ps1`), then `-Gate -BaseRef origin/main` over the whole range including SPEC-251's commits, candidate CI, `main` CI after exact-SHA promotion, and `-Certify`.

## Implementation Steps

Every file is written LF. The "from" hashes are SPEC-251's committed bytes at `78853c7`; the "to" hashes were measured on the prototype.

1. **Check** whether `scripts/check_agent_continuity.ps1` contains `function Get-CharacterBoundary`. If absent, write the evaluator and its suite exactly as prototyped:
   - `scripts/check_agent_continuity.ps1` from `21fa36ab7aeda9b7a69898d4253c76a52e854758a83e67fde66a44dd4bd0d06e` to `744bd40910c5c71e961f1ef4f745b881e350f5d1d484392d256bdfddceaaad38`
   - `scripts/test_agent_continuity.ps1` from `7abb8a46b1fd765214fffcef8866431e4a97142e910357a520d80bf566195735` to `5ab32fd110593f2ddc9bb6f5be59eab4eda154ebe0ba461a2518db80a98e643f`

   If either holds bytes other than its "from" hash, or a resulting hash differs, stop.
2. **Check** whether `CR_LIFECYCLE.md` contains `The boundary cannot be moved`. If absent, apply exactly as prototyped:
   - `CR_LIFECYCLE.md` from `3ba1d297ce3be8ded26d7641f2a75f0b59e8bca9583667fd5dbbc4bac8eb2a3a` to `cb85884c5177e5170d7f8e5187a75e10d4994e721782fef4f31952cc90f0aeb9`
   - `CODING_STANDARDS.md` from `066e36bf98c3e2f440d3cf504395a60a9d3ea4f5ce283b71c39917b09b037a42` to `25e4769355fd5fb46feca3e9741b87ddd074bbb6efa67c9dc40110032b8f6c02`

   If either holds bytes other than its "from" hash, or a resulting hash differs, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` contains `| CTRL-6 |`. If absent, apply exactly as prototyped:
   - `reports/master/MASTER_GAP_REGISTER.md` from `f0c0e5e37b5a07f15d271d1e916155dae80239a6a01034c49ce0c4ee2e21eb12` to `23cabd7c77be82509093364354117c6b776d0a27afeccf57a10f347da65d9888`
   - `reports/master/MASTER_EXECUTION_PLAN.md` from `736cf8c6db526e12aab74dabc4d3565cd473a5b60b440bdee4bb4890483039e1` to `3c82fde4a6465e79a6a6eb35589667e6e4ba467db555955b0f3349655cce133a`

   If either holds bytes other than its "from" hash, or a resulting hash differs, stop.
4. **Check** for a `Local certification` Execution Log entry. If absent:
   - commit steps 1 to 3 with an Execution Log entry;
   - commit the Runtime Checkpoint as `Resume Step: DONE`;
   - run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` once, on the clean committed tree, and require `LOCAL_CERTIFY: READY`.

   No step runs any command that `-Finish` runs.
5. **Check** whether the manifest's `Last Completed` begins `**SPEC-252`. If not:
   - set it to this contract, with the Active pointer `None.`;
   - leave `Current Module`, `Next capability` (Batch 6 Slice 35) and the open-decision line unchanged;
   - keep the manifest within 7000 characters and 1200 per line;
   - regenerate `ai-map.json` with `scripts/generate-ai-map.ps1` and convert it to LF.

   Then Review, and Complete.

## Acceptance Criteria

- [ ] `scripts/check_agent_continuity.ps1` (`744bd409…`) keeps SPEC-251's ordinal comparisons and character rule, and `Get-CharacterBoundary` yields a boundary only for a declared value in the declaring commit's history that equals the value first committed; otherwise the rule applies everywhere.
- [ ] `scripts/test_agent_continuity.ps1` (`5ab32fd1…`) carries CTRL4-1 to CTRL4-27, fifteen CTRL-4 mutants and the `CTRL4` population family, and passes in `-Finish`, including CTRL4-26 on this repository's history.
- [ ] CTRL4-24, CTRL4-25 and CTRL4-27 refuse both reproduced bypasses and the isolated first-declaration case, in CI's range shape with no pre-commit hook.
- [ ] `CR_LIFECYCLE.md` (`cb85884c…`) declares `Evidence Character Enforcement: ae1d130d82a1173099d858e667aab8dc88650d84`, states that the boundary cannot be moved, and both existing marker lines are byte-unchanged.
- [ ] `CODING_STANDARDS.md` (`25e47693…`) carries one added rule on exact comparison and deliberate text construction.
- [ ] The register (`23cabd7c…`) records CTRL-4 fixed and CTRL-5, CTRL-6, CI-2, TEST-4, PERF-2, OPS-3 and OPS-4 open, each with owner and trigger; the execution plan (`3c82fde4…`) names them without restating any status; `scripts/readiness_population.ps1` exits 0.
- [ ] SPEC-251 stays Cancelled and unmodified by this contract; no historical contract is modified; SPEC-239's BEL is preserved.
- [ ] At Complete, the manifest names this contract, its `Next capability` is still Batch 6 Slice 35, its open-decision line is MAIL-1, RET-1 and PH8-10, and `ai-map.json` is regenerated LF.
- [ ] No migration, database test or Primary object changed, and no SPEC identity after this one is named in any changed file.
- [ ] No file outside Write Scope was created, modified or deleted.

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

**Prototype evidence**, measured 2026-10-09 on `DESKTOP-0U3LC2V` (pwsh 7.6.6, 8 logical CPUs) on a local scratch branch at `090fa44` that was never pushed; its evaluator equals the "to" hash above. Every figure was copied from the run's own output.

- **Identity.** The canonical allocator, probed with uncommitted Drafts after SPEC-251's cancellation, refused SPEC-253 with `SPEC_ID_NOT_NEXT:252:253` and accepted SPEC-252.
- **The CTRL-4 block alone:** 43 passed, 0 failed; populations accept 8, reject 19, mutation 15; every mutant applied.
- **The full suite on the final bytes:** `AGENT CONTROL TESTS: 374 passed, 0 failed` in 44.1 min, under concurrent load; CTRL4-26 passed on the prototype branch's history.
- **The four guard self-tests on the final bytes:** cold-start 34/0, status contradiction 33/0, Primary ledger 13/0, future date 18/0, in 17.0 min.
- **Repository consistency:** CLEAN. **Readiness population:** every derived id named, exit 0.
- **The pin on real history, hook skipped.** In clones of the prototype branch:
  - unchanged: the pin passes and the boundary is `ae1d130`;
  - marker moved forward to a later commit: the pin fails (`first-declared=ae1d130`) and the evaluator finds no boundary;
  - marker re-pointed at an orphan-branch commit: the pin fails (not in history) and the evaluator finds no boundary.

  ORVION Acceptance runs both the suite and the range Gate on every candidate, so either layer alone refuses a moved marker in CI.
- **Historical replay, three equivalent conditions.** Every run is from a clone at a short path (`C:\r251`, `C:\r252src`) with `core.autocrlf=false`, so neither Windows MAX_PATH nor a CRLF working copy differs from CI's Linux checkout:
  - (1) CI-equivalent: each head checked out and judged by its own evaluator, as Agent Control invokes it;
  - (2) and (3) differential: one Root carrying the committed declaration, the same historical `-BaseRef`/`-HeadRef`, judged by the `ae1d130` evaluator and by this one.

  All thirteen ranges `73e571c..ae1d130` read `ORVION: READY` under all three, each naming its own CR (SPEC-238 to SPEC-250): 0 differences, 0 not ready.
- **SPEC-251's own evidence is not reused for the changed bytes.** Its `LOCAL_CERTIFY: READY` at `48cdcdd` is historical. Every figure above was measured on this contract's final bytes.
- **Separate engineering observation, recorded as CTRL-6 and not repaired here.** `Read-GitFile` reads any git failure as "file absent". On Windows, from a working directory about 165 characters deep, `git show <40-character sha>:<long path>` fails with `Filename too long`. That made a local replay refuse SPEC-247's and SPEC-250's ranges, which CI had accepted. It does not block these acceptance tests or present release certification: CI runs on Linux, and this checkout's worst case is 192 of 259 characters.
