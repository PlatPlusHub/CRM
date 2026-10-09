# Change Request — SPEC-254

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make approved and recorded contract text resistant to invisible, case-only and Unicode-equivalence mutations, with a forward-only activation boundary that cannot be moved or re-pointed, exactly as SPEC-252 implemented and locally certified it, under an acceptance contract that is true.

## Business Reason

- **The owner's decision (2026-10-09, Option B):** SPEC-252's implementation is technically sound, but its Acceptance Criterion 9 was demonstrably false, and an owner-approved deviation must not be represented as a satisfied criterion. SPEC-252 is cancelled; this minimal successor keeps its proven implementation and corrects only the acceptance-contract defect and the lifecycle references that depend on it.
- **SPEC-252's defect.** Its criterion 9 requires that no SPEC identity after it is named in any changed file, and its own Notes named the allocator's refused probe, SPEC-253. Under `CR_LIFECYCLE.md`'s collision rule (`SPEC-163`) that mention retired SPEC-253, which is why the canonical allocator chose this identity (`SPEC_ID_ALREADY_USED:SPEC-253`). This contract names no identity after its own.
- **The capability, unchanged from SPEC-252.** A PowerShell escape committed a NUL into SPEC-250 and a BEL into SPEC-239. On the evaluator at `ae1d130`, fourteen attacks on frozen or recorded text were admitted with `ORVION: READY`. SPEC-251 repaired them and was cancelled because a contract owning `CR_LIFECYCLE.md` could move or re-point its activation marker; SPEC-252 closed that and reached `LOCAL_CERTIFY: READY`.

## Risks

- **The behaviour is SPEC-252's, proven unchanged.** Against SPEC-252's committed bytes, the two scripts differ only in comments: their PowerShell token streams with comments removed are identical. The remaining four files differ only in which contract they name.
- **A legitimate contract could be newly refused.** Measured not to happen on these behaviours: over the thirteen publication ranges `73e571c..ae1d130`, each head's own evaluator, the `ae1d130` evaluator and this evaluator all read `ORVION: READY`.
- **The boundary reading is stricter, never looser.** A marker that is missing, malformed, unknown, outside the declaring history, or different from its first committed value yields no boundary, so the rule applies everywhere.
- **History.** No contract is rewritten. SPEC-251 and SPEC-252 are Cancelled and preserved; their files are in this Write Scope only because their cancellations lie in this publication range. SPEC-239's BEL stays.
- **No Primary access, migration or database test.**

## Supersedes / Depends On

Supersedes SPEC-252 (`changes/SPEC-252-recorded-contract-text-is-compared-by-code-point-from-a-pinned-boundary.md`), Cancelled at `619376a`, and through it SPEC-251 (`changes/SPEC-251-recorded-contract-text-is-compared-by-code-point.md`), Cancelled at `78853c7`. Both were cancelled by human command before publication. SPEC-239 and SPEC-250 are Complete and are not modified.

## Write Scope

- `changes/SPEC-254-recorded-contract-text-is-compared-by-code-point-from-a-pinned-boundary.md`
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

- `changes/SPEC-252-recorded-contract-text-is-compared-by-code-point-from-a-pinned-boundary.md` and `changes/SPEC-251-recorded-contract-text-is-compared-by-code-point.md`, in full, including their cancellation entries
- `CR_LIFECYCLE.md` §4, §8 and the three declared-marker paragraphs; `CODING_STANDARDS.md §12`
- `scripts/check_agent_continuity.ps1`: `Validate-FrozenAuthority`, `Validate-EvidenceAppendOnly`, `Validate-Checklist`, `Get-CharacterBoundary`, `Character-Guard-IsActive`, `Validate-CommittedRange` and the endpoint block
- `scripts/test_agent_continuity.ps1`: `MutationKill`, `MutationKillRangeAt`, `Pop`, case 119i, the CTRL-4 block and the NON-EMPTY POPULATIONS loop

## Runtime Checkpoint

Resume Step: DONE
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
| The CTRL-4 evaluator: ordinal comparisons, `Validate-NoNewProhibitedCharacter` at the endpoint and per commit, and `Get-CharacterBoundary` (SPEC-252's behaviour; comments now name this contract) | Every Gate: the pre-commit hook, `-Finish`, Agent Control and ORVION Acceptance (`-Gate -BaseRef`); every governed contract | WRITE | Non-comment tokens are identical to SPEC-252's `744bd409…`, so SPEC-252's measured behaviour holds: CTRL4-1 to CTRL4-27, fifteen mutant kills, 374/0 in the full suite, and `LOCAL_CERTIFY: READY` at `d9a5d75`. |
| The CTRL-4 suite (`scripts/test_agent_continuity.ps1`) | ORVION Acceptance (runs the suite with `fetch-depth: 0`) and Agent Control on feature branches; `-Finish` (CONTROL) | WRITE | Non-comment tokens are identical to SPEC-252's `5ab32fd1…`. CTRL4-26 reads the repository's first declaration, SPEC-251's Implement `8e9cbe5`, whose value is `ae1d130…`. |
| `Evidence Character Enforcement` and its paragraphs in `CR_LIFECYCLE.md`, now attributed to this contract | The Gate; case CTRL4-26; the existing `SPEC Allocation Enforcement` and `Historical CR Immutability Enforcement` lines | WRITE | The marker line and both existing marker lines are byte-unchanged; only the attribution `SPEC-252` becomes `SPEC-254`. |
| `CODING_STANDARDS.md §12`: the CTRL-4 rule, now attributed to this contract | Authors; no parser | WRITE | One attribution changes. |
| `MASTER_GAP_REGISTER.md`: CTRL-4 fixed by this contract (with its two cancelled carriers named); CTRL-5, CTRL-6, CI-2, TEST-4, PERF-2, OPS-3 and OPS-4 open | Checks 2, 11, 14, 21 and 25; `scripts/readiness_population.ps1`; the open-decision pin in `test_cold_start_state_guard.ps1` | WRITE | No status, owner or trigger changes, and Owner Decision stays `—`. Prototype: repository consistency CLEAN. |
| `MASTER_EXECUTION_PLAN.md`: CTRL-6 attributed to this contract | `scripts/readiness_population.ps1`, which derives every status from the register | WRITE | The plan carries ids and no status. Prototype: every derived id named, exit 0. |
| Historical publication ranges on `origin/main` | Anyone replaying a published range | VERIFY | Thirteen ranges, three conditions, 39 verdicts, all `ORVION: READY`, measured on SPEC-252's evaluator, whose non-comment tokens equal this one's. |
| SPEC-251's and SPEC-252's contracts, Cancelled | The range Gate (both cancellations lie in this publication range); Check 2 | VERIFY | Not modified by this contract; listed in Write Scope so the range's net diff is authorized. |
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
- SPEC-252's evaluator and suite, carried forward with identical non-comment tokens.
- CTRL-1's declared-boundary pattern in `CR_LIFECYCLE.md` and its repository pin, case 119i.
- Git ancestry (`merge-base --is-ancestor`) and the authority's own history (`log -G`).
- The suite's `MutationKill`, `MutationKillRangeAt`, `Pop` and NON-EMPTY POPULATIONS.

Nothing is added beyond SPEC-252. No mode, switch, file, workflow or capability.

Added Property: Frozen sections, Out of Scope, Execution Log and Verification Notes prefixes, and Acceptance Criteria and Review Gate wording are equal only when their code points are equal after the existing CRLF and trim normalization. A governed contract may not gain a C0 control other than TAB, LF and a CRLF's CR, a DEL or C1 control, or an invisible format character. The rule exempts a transition only when its before-state predates a boundary that lies in the history of the declaring commit and equals the value first committed in `CR_LIFECYCLE.md`; in this repository that value is `ae1d130…`.

Causal Negative:
- **The evaluator at `ae1d130`** admitted CTRL4-1 to CTRL4-14 with `ORVION: READY` and `MODE: EXECUTE`.
- **SPEC-251's evaluator (`21fa36ab…`)**, in a sandbox with no pre-commit hook, admitted with `ORVION: READY` a contract owning `CR_LIFECYCLE.md` that either re-pointed the marker at an unrelated branch and added a BEL, or added a BEL and moved the marker forward past it.

Positive Test Design: CTRL4-15 to CTRL4-21 (TAB, symbols, an emoji selector and accents; multiline appends; unchanged non-ASCII history; a CRLF working copy; non-ASCII checkbox moves; SPEC-239-style historical BEL; a character added before the boundary) and CTRL4-26, the repository pin on real history.

Negative Test Design: CTRL4-1 to CTRL4-14, CTRL4-22 and CTRL4-23; CTRL4-24 marker moved forward past the BEL; CTRL4-25 marker re-pointed at an unrelated branch; CTRL4-27 first declaration outside the declaring history. The last three run through `RunRange`, the CI invocation shape, in a sandbox that has no hook.

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

SPEC-251's mutant `$ancestorCode-ne1` to `$ancestorCode-eq0` stays retired as EQUIVALENT and is not counted.

Post-Implementation Proof Obligation: On the final committed bytes, canonical `-Finish` (CONTROL and REPOSITORY: agent continuity with every CTRL-4 case and mutant including CTRL4-26 on real history, the four guard self-tests, repository consistency and `scripts/readiness_population.ps1`), then `-Gate -BaseRef origin/main` over the whole range including SPEC-251's and SPEC-252's commits, candidate CI, `main` CI after exact-SHA promotion, and `-Certify`.

## Implementation Steps

Every file is written LF. The "from" hashes are SPEC-252's committed bytes at `619376a`; the "to" hashes were measured on the prototype.

1. **Check** whether `scripts/check_agent_continuity.ps1` contains `# CTRL-4 (SPEC-254).`. If absent, write the evaluator and its suite exactly as prototyped:
   - `scripts/check_agent_continuity.ps1` from `744bd40910c5c71e961f1ef4f745b881e350f5d1d484392d256bdfddceaaad38` to `d5f1e1d315e11acb22564f8c673bc426e8cddcb7eb8fcc1320040194214a48ad`
   - `scripts/test_agent_continuity.ps1` from `5ab32fd110593f2ddc9bb6f5be59eab4eda154ebe0ba461a2518db80a98e643f` to `6c03f9319fc478c23cbb59ff9be9a5b83c49ee9def3909a75121a792852a86c6`

   If either holds bytes other than its "from" hash, or a resulting hash differs, stop.
2. **Check** whether `CR_LIFECYCLE.md` contains ``The boundary cannot be moved (`SPEC-254`)``. If absent, apply exactly as prototyped:
   - `CR_LIFECYCLE.md` from `cb85884c5177e5170d7f8e5187a75e10d4994e721782fef4f31952cc90f0aeb9` to `1256fb645f547b9620f350998862804e29ec17bde89b2406554e3024953c3b02`
   - `CODING_STANDARDS.md` from `25e4769355fd5fb46feca3e9741b87ddd074bbb6efa67c9dc40110032b8f6c02` to `5344a44eef46c95f2ffcac8172363cf7be67ae62f201b4e342a69edc4cdf3079`

   If either holds bytes other than its "from" hash, or a resulting hash differs, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` contains `FIXED 2026-10-09 (SPEC-254)`. If absent, apply exactly as prototyped:
   - `reports/master/MASTER_GAP_REGISTER.md` from `23cabd7c77be82509093364354117c6b776d0a27afeccf57a10f347da65d9888` to `979ae384bd92becba5a40a0bb52afc9e133efa5cddd67c0c9b0068e9cc27f985`
   - `reports/master/MASTER_EXECUTION_PLAN.md` from `3c82fde4a6465e79a6a6eb35589667e6e4ba467db555955b0f3349655cce133a` to `29842fe769329d348688ed9586479f126e8696d75fcf3816528376a5cc5739d1`

   If either holds bytes other than its "from" hash, or a resulting hash differs, stop.
4. **Check** for a `Local certification` Execution Log entry. If absent:
   - commit steps 1 to 3 with an Execution Log entry;
   - commit the Runtime Checkpoint as `Resume Step: DONE`;
   - run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` once, on the clean committed tree, and require `LOCAL_CERTIFY: READY`.

   No step runs any command that `-Finish` runs.
5. **Check** whether the manifest's `Last Completed` begins `**SPEC-254`. If not:
   - set it to this contract, with the Active pointer `None.`;
   - leave `Current Module`, `Next capability` (Batch 6 Slice 35) and the open-decision line unchanged;
   - keep the manifest within 7000 characters and 1200 per line;
   - regenerate `ai-map.json` with `scripts/generate-ai-map.ps1` and convert it to LF.

   Then Review, and Complete.

## Acceptance Criteria

- [ ] `scripts/check_agent_continuity.ps1` (`d5f1e1d3…`) compares frozen sections, Out of Scope, evidence prefixes and checklist wording ordinally, refuses a new prohibited character at the endpoint and per commit, and yields a boundary only for a declared value in the declaring commit's history that equals the value first committed; otherwise the rule applies everywhere.
- [ ] `scripts/test_agent_continuity.ps1` (`6c03f931…`) carries CTRL4-1 to CTRL4-27, fifteen CTRL-4 mutants and the `CTRL4` population family, and passes in `-Finish`, including CTRL4-26 on this repository's history.
- [ ] CTRL4-24, CTRL4-25 and CTRL4-27 refuse both reproduced bypasses and the isolated first-declaration case, in CI's range shape with no pre-commit hook.
- [ ] `CR_LIFECYCLE.md` (`1256fb64…`) declares `Evidence Character Enforcement: ae1d130d82a1173099d858e667aab8dc88650d84`, states that the boundary cannot be moved, and both existing marker lines are byte-unchanged.
- [ ] `CODING_STANDARDS.md` (`5344a44e…`) carries one added rule on exact comparison and deliberate text construction.
- [ ] The register (`979ae384…`) records CTRL-4 fixed by this contract and CTRL-5, CTRL-6, CI-2, TEST-4, PERF-2, OPS-3 and OPS-4 open, each with owner and trigger; the execution plan (`29842fe7…`) names them without restating any status; `scripts/readiness_population.ps1` exits 0.
- [ ] SPEC-251 and SPEC-252 stay Cancelled and unmodified by this contract; no historical contract is modified; SPEC-239's BEL is preserved.
- [ ] At Complete, the manifest names this contract, its `Next capability` is still Batch 6 Slice 35, its open-decision line is MAIL-1, RET-1 and PH8-10, and `ai-map.json` is regenerated LF.
- [ ] No migration, database test or Primary object changed, and no SPEC identity after this one is named in any changed file.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-10-09 — Gate 1 approval and execution started

- **Authority:** the owner's SPEC-254 Gate 1 approval of 2026-10-09, conditional on the exact frozen Draft. Verified before acting: the Draft commit is `0bebc76e9eb6b82b5e43c72993ef1dead640f85a`, and the contract's SHA-256 is `fa1513a7599ca595620aece8ea691810cfc748da72797aa4cc75903a3be7f256`, equal to the committed blob. A read-only probe of the evaluator derived profiles `CONTROL,REPOSITORY` and returned `APPROVAL_EVIDENCE: PASS`; Approval was committed at `2ef307f`, where the Gate printed `APPROVAL_EVIDENCE: PASS`.
- **Preconditions:** each of the six files in this checkout equals its "from" hash, and each prototype file on the local scratch branch (`578f3fb`, never pushed) equals its "to" hash.
- **No Primary write is authorized or expected.** Secondary is never contacted.

### 2026-10-09 — Steps 1-3 executed

- **Checks:** `# CTRL-4 (SPEC-254).`, ``The boundary cannot be moved (`SPEC-254`)`` and `FIXED 2026-10-09 (SPEC-254)` were each absent, so every step applied.
- **Applied exactly as prototyped.** All six full SHA-256s equal the frozen "to" values: `d5f1e1d3…` (evaluator), `6c03f931…` (suite), `1256fb64…` (`CR_LIFECYCLE.md`), `5344a44e…` (`CODING_STANDARDS.md`), `979ae384…` (register), `29842fe7…` (execution plan).
- **The diff against `095187b` is byte-identical to the prototype's increment over SPEC-252 (`090fa44..578f3fb`):** six files, 12 insertions, 12 deletions. Every file is LF, and `git diff --check` is clean.

### 2026-10-09 — Local certification

- `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` ran once on the clean committed tree at `1149a2d`, through `scripts/run_timed.ps1` with `concurrent=0` from start to end, watched by `scripts/watch_run.ps1`.
- Every step printed `PASS`:

  | Step | Time |
  | --- | --- |
  | `test_agent_continuity.ps1` | 28.2 min |
  | cold-start guard | 4.5 min |
  | status-contradiction guard | 3.4 min |
  | Primary-ledger guard | 0.3 min |
  | future-date guard | 3.0 min |
  | repository consistency, `git diff --check` and `scripts/readiness_population.ps1` | 0.3 min together |

  The result was `LOCAL_CERTIFY: READY` in 40.1 min, `exit=0`.
- This result is recorded as evidence. It does not authorize Complete.

## Verification Notes

### 2026-10-09 — Review: Acceptance Criterion 9 is false as written

Verdict: Needs Corrective Change Request

Findings, checked against the live repository at `1149a2d`, not against the Execution Log:

- **Criteria 1 to 8 and 10 are true.** The six files equal their frozen "to" hashes. `-Finish` passed the suite, including CTRL4-1 to CTRL4-27, the fifteen mutants and CTRL4-26 on real history. Both existing marker lines are byte-unchanged. `CODING_STANDARDS.md` gains one line and loses none. The register and plan read as Criterion 6 states, and `scripts/readiness_population.ps1` exits 0. SPEC-251 and SPEC-252 are unchanged since `78853c7` and `619376a`, no other contract changed, and SPEC-239 still holds one BEL. No path under `supabase/` changed. Every path changed in `origin/main..HEAD` is in Write Scope. Criterion 8 is a Step 5 state that is reachable within the manifest budget.
- **Criterion 9 is false.** It requires that "no SPEC identity after this one is named in any changed file". Changed files name later identities: `CR_LIFECYCLE.md` and the evaluator name three real historical contracts with four-digit identities, the register names an example identity, and the suite names its fixture identities. All of them were already present on `origin/main`, and this range adds only one line naming an already-used fixture identity. The criterion can never be true for these files, whatever this contract does.
- **The criterion is also redundant.** SPEC identity is decided mechanically by `Validate-SpecAllocation` and the allocator (`CR_LIFECYCLE.md` §4; `SPEC-163`, `SPEC-196`). `changes/TEMPLATE.md` already states that SPEC identity is not recorded in a contract, because the allocator is its sole authority (`SPEC-210`). The criterion restated machine truth, and restated it wrongly.
- **No lawful completion path exists.** Acceptance Criteria wording is frozen after Approval (`CR_LIFECYCLE.md` §8). Complete requires every item to be ticked, and no waiver mechanism exists. Ticking Criterion 9 would record a falsehood. This is the SPEC-200 precedent: the engineering is green and the frozen contract text is defective.
- **Review Gate.** Every step matches the Implementation Steps, no file outside Write Scope changed, no section was restructured, and nothing was guessed. The item "Every Acceptance Criteria item is confirmed true" fails on Criterion 9.

Nothing here weakens the repair. The implementation, its tests and this contract's `LOCAL_CERTIFY: READY` are preserved in history.

Recommendation to human: Set Status to Cancelled. A minimal successor keeps this implementation's behaviour, deletes Criterion 9 without replacement, and changes only the attribution text that names this contract.

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

**What is new here, and what is carried.** Measured 2026-10-09 on `DESKTOP-0U3LC2V` (pwsh 7.6.6, 8 logical CPUs) on a local scratch branch at `578f3fb` that was never pushed.

- **Identity.** After SPEC-252's cancellation, the canonical allocator, probed with uncommitted Drafts, refused SPEC-253 (`SPEC_ID_ALREADY_USED`) and accepted SPEC-254.
- **New evidence on these bytes.**
  - For both scripts, the PowerShell token streams with comments removed are identical to SPEC-252's committed bytes. The six changed script lines are comments that named SPEC-252.
  - Repository consistency is CLEAN, `scripts/readiness_population.ps1` exits 0, `git diff --check` is clean, and no file holds a CR or a prohibited character.
  - The full diff from SPEC-252's bytes is six files, 12 lines changed, all attribution text.
- **Carried evidence, valid because the behaviour is token-identical.** All of it was measured on SPEC-252's bytes:
  - the full suite, `AGENT CONTROL TESTS: 374 passed, 0 failed`;
  - the CTRL-4 block at 43/0 with populations 8, 19 and 15;
  - the four guard self-tests at 34/0, 33/0, 13/0 and 18/0;
  - the pin negative on real history: a moved or re-pointed marker turns CTRL4-26 red, and the evaluator then finds no boundary;
  - the 39-verdict historical replay, all `ORVION: READY`, from short-path clones with `core.autocrlf=false`;
  - SPEC-252's canonical `-Finish`, `LOCAL_CERTIFY: READY` in 40.4 min at `d9a5d75`.

  None of it replaces this contract's own `-Finish`, which Step 4 requires.
- **Separate engineering observation, recorded as CTRL-6 and not repaired.** `Read-GitFile` reads any git failure as "file absent". On Windows, a deep working directory plus a long `rev:path` fails with `Filename too long`, which made a local replay refuse two ranges CI had accepted. It does not affect CI or this checkout (worst case 192 of 259 characters).
