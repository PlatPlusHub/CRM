# Change Request — SPEC-255

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make approved and recorded contract text resistant to invisible, case-only and Unicode-equivalence mutations, with a forward-only activation boundary that cannot be moved or re-pointed, exactly as SPEC-252 implemented it and SPEC-254 locally certified it, under an acceptance contract whose every criterion is true.

## Business Reason

- **The owner's decision (2026-10-09):** proceed with the bounded corrective plan. SPEC-254's Review found its Acceptance Criterion 9 false as written, and the owner cancelled it at `33e4db6` with no waiver. This successor keeps SPEC-254's implementation unchanged in behaviour, deletes that criterion without replacement, and changes only the attribution text that names the cancelled contract. SPEC-200 to SPEC-201 is the precedent.
- **SPEC-254's defect.** Its criterion 9 required that no later SPEC identity is named in any changed file. `CR_LIFECYCLE.md`, the evaluator, the register and the suite already named later identities on `origin/main`: real historical contracts and test fixtures. The criterion was also redundant. SPEC identity is decided by `Validate-SpecAllocation` and the allocator (`CR_LIFECYCLE.md` §4; `SPEC-163`, `SPEC-196`), and `changes/TEMPLATE.md` states that a contract does not record it (`SPEC-210`). This contract asserts nothing about SPEC identity.
- **The capability, unchanged since SPEC-252.** A PowerShell escape committed a NUL into SPEC-250 and a BEL into SPEC-239. On the evaluator at `ae1d130`, fourteen attacks on frozen or recorded text were admitted with `ORVION: READY`. SPEC-251 repaired them and was cancelled because a contract owning `CR_LIFECYCLE.md` could move or re-point its activation marker. SPEC-252 closed that, and SPEC-252 and SPEC-254 each reached `LOCAL_CERTIFY: READY`.

## Risks

- **The behaviour is SPEC-254's, proven unchanged.** Against SPEC-254's committed bytes, the two scripts differ only in comments: their PowerShell token streams with comments removed are identical (14116 and 27625 tokens). The other four files differ only in which contract they name, plus one register sentence that lists SPEC-254 among the cancelled carriers.
- **A legitimate contract could be newly refused.** Measured not to happen on these behaviours: over the thirteen publication ranges `73e571c..ae1d130`, each head's own evaluator, the `ae1d130` evaluator and SPEC-252's evaluator, whose non-comment tokens equal this one's, all read `ORVION: READY`.
- **The boundary reading is stricter, never looser.** A marker that is missing, malformed, unknown, not an ancestor of the evaluated HEAD, or different from its first committed value yields no boundary, so the rule applies everywhere.
- **History.** No contract is rewritten. SPEC-251, SPEC-252 and SPEC-254 are Cancelled and preserved. Their files are in this Write Scope only because their cancellations lie in this publication range. SPEC-239's BEL stays.
- **No Primary access, migration or database test.**

## Supersedes / Depends On

Supersedes SPEC-254 (`changes/SPEC-254-recorded-contract-text-is-compared-by-code-point-from-a-pinned-boundary.md`), Cancelled at `33e4db6`. Through it, it also supersedes SPEC-252 (`changes/SPEC-252-recorded-contract-text-is-compared-by-code-point-from-a-pinned-boundary.md`), Cancelled at `619376a`, and SPEC-251 (`changes/SPEC-251-recorded-contract-text-is-compared-by-code-point.md`), Cancelled at `78853c7`. All three were cancelled by human command before publication. SPEC-239 and SPEC-250 are Complete and are not modified.

## Write Scope

- `changes/SPEC-255-recorded-contract-text-is-compared-by-code-point-from-a-pinned-boundary.md`
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

- `changes/SPEC-254-recorded-contract-text-is-compared-by-code-point-from-a-pinned-boundary.md`, in full, including its Review and cancellation entries; SPEC-252's and SPEC-251's cancellation entries
- `CR_LIFECYCLE.md` §4, §8 and the three declared-marker paragraphs; `CODING_STANDARDS.md §12`
- `scripts/check_agent_continuity.ps1`: `Validate-FrozenAuthority`, `Validate-EvidenceAppendOnly`, `Validate-Checklist`, `Get-CharacterBoundary`, `Character-Guard-IsActive`, `Validate-CommittedRange` and the endpoint block
- `scripts/test_agent_continuity.ps1`: `MutationKill`, `MutationKillRangeAt`, `Pop`, case 119i, the CTRL-4 block and the NON-EMPTY POPULATIONS loop

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
| The CTRL-4 evaluator: ordinal comparisons, `Validate-NoNewProhibitedCharacter` at the endpoint and per commit, and `Get-CharacterBoundary` (SPEC-252's behaviour; comments now name this contract) | Every Gate: the pre-commit hook, `-Finish`, Agent Control and ORVION Acceptance (`-Gate -BaseRef`); every governed contract | WRITE | Non-comment tokens are identical to SPEC-254's `d5f1e1d3…`, which are identical to SPEC-252's `744bd409…`. The measured behaviour therefore holds: CTRL4-1 to CTRL4-27, fifteen mutant kills, and `LOCAL_CERTIFY: READY` at `1149a2d` (SPEC-254) and `d9a5d75` (SPEC-252). |
| The CTRL-4 suite (`scripts/test_agent_continuity.ps1`) | ORVION Acceptance (runs the suite with `fetch-depth: 0`) and Agent Control on feature branches; `-Finish` (CONTROL) | WRITE | Non-comment tokens are identical to SPEC-254's `6c03f931…`. CTRL4-26 reads the repository's first declaration, SPEC-251's Implement `8e9cbe5`, whose value is `ae1d130…`. |
| `Evidence Character Enforcement` and its paragraphs in `CR_LIFECYCLE.md`, now attributed to this contract | The Gate; case CTRL4-26; the existing `SPEC Allocation Enforcement` and `Historical CR Immutability Enforcement` lines | WRITE | All three marker lines are byte-unchanged. Only the attribution `SPEC-254` becomes `SPEC-255`. |
| `CODING_STANDARDS.md §12`: the CTRL-4 rule, now attributed to this contract | Authors; no parser | WRITE | One attribution changes. |
| `MASTER_GAP_REGISTER.md`: CTRL-4 fixed by this contract, with its three cancelled carriers named; CTRL-5, CTRL-6, CI-2, TEST-4, PERF-2, OPS-3 and OPS-4 open | Checks 2, 11, 14, 21 and 25; `scripts/readiness_population.ps1`; the open-decision pin in `test_cold_start_state_guard.ps1` | WRITE | No status, owner or trigger changes, and Owner Decision stays `—`. Prototype: repository consistency CLEAN; `scripts/readiness_population.ps1` exit 0. |
| `MASTER_EXECUTION_PLAN.md`: CTRL-6 attributed to this contract | `scripts/readiness_population.ps1`, which derives every status from the register | WRITE | The plan carries ids and no status. Prototype: every derived id named, exit 0. |
| Historical publication ranges on `origin/main` | Anyone replaying a published range | VERIFY | Thirteen ranges, three conditions, 39 verdicts, all `ORVION: READY`, measured on SPEC-252's evaluator, whose non-comment tokens equal this one's. |
| SPEC-251's, SPEC-252's and SPEC-254's contracts, Cancelled | The range Gate (all three cancellations lie in this publication range); Check 2 | VERIFY | Not modified by this contract; listed in Write Scope so the range's net diff is authorized. |
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
- SPEC-254's evaluator and suite, which carry SPEC-252's behaviour, carried forward with identical non-comment tokens.
- CTRL-1's declared-boundary pattern in `CR_LIFECYCLE.md` and its repository pin, case 119i.
- Git ancestry (`merge-base --is-ancestor`) and the authority's own history (`log -G`).
- The suite's `MutationKill`, `MutationKillRangeAt`, `Pop` and NON-EMPTY POPULATIONS.

Nothing is added beyond SPEC-252. No mode, switch, file, workflow or capability.

Added Property: Frozen sections, Out of Scope, Execution Log and Verification Notes prefixes, and Acceptance Criteria and Review Gate wording are equal only when their code points are equal after the existing CRLF and trim normalization. A governed contract may not gain a C0 control other than TAB, LF and a CRLF's CR, a DEL or C1 control, or an invisible format character. The rule exempts a transition only when its before-state predates a boundary that is an ancestor of the evaluated HEAD and equals the value first committed in `CR_LIFECYCLE.md`; in this repository that value is `ae1d130…`.

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

Post-Implementation Proof Obligation: On the final committed bytes, canonical `-Finish` (CONTROL and REPOSITORY: agent continuity with every CTRL-4 case and mutant including CTRL4-26 on real history, the four guard self-tests, repository consistency and `scripts/readiness_population.ps1`), then `-Gate -BaseRef origin/main` over the whole range including SPEC-251's, SPEC-252's and SPEC-254's commits, candidate CI, `main` CI after exact-SHA promotion, and `-Certify`.

## Implementation Steps

Every file is written LF. The "from" hashes are SPEC-254's committed bytes at `33e4db6`. The "to" hashes were measured on the prototype: a scratch worktree from `33e4db6`, never committed or pushed, whose diff is preserved as a 33077-byte patch with SHA-256 `d6acf25f252f193570eebd594fb3bd914756f8401b50e8b8eda5406d439cd6be`.

1. **Check** whether `scripts/check_agent_continuity.ps1` contains `# CTRL-4 (SPEC-255).`. If absent, write the evaluator and its suite exactly as prototyped:
   - `scripts/check_agent_continuity.ps1` from `d5f1e1d315e11acb22564f8c673bc426e8cddcb7eb8fcc1320040194214a48ad` to `e40be2e7e51b5a6bd0ce0181de9e69fb047bdaebcdc38f891c569d9a4540b369`
   - `scripts/test_agent_continuity.ps1` from `6c03f9319fc478c23cbb59ff9be9a5b83c49ee9def3909a75121a792852a86c6` to `c2ce82d8d6b654418b8be1fc56e72332448fc47bd9753f173b0bf9d78e6b5d5c`

   If either holds bytes other than its "from" hash, or a resulting hash differs, stop.
2. **Check** whether `CR_LIFECYCLE.md` contains ``The boundary cannot be moved (`SPEC-255`)``. If absent, apply exactly as prototyped:
   - `CR_LIFECYCLE.md` from `1256fb645f547b9620f350998862804e29ec17bde89b2406554e3024953c3b02` to `6b70b792e1ab99e5597635d0ac2f4ec42bd9f15c0551f7ebdd3cf909606283d4`
   - `CODING_STANDARDS.md` from `5344a44eef46c95f2ffcac8172363cf7be67ae62f201b4e342a69edc4cdf3079` to `847bc709226a9f2007b9eab1765e33f9334895ade9ffa0c542ee9b68381fb916`

   If either holds bytes other than its "from" hash, or a resulting hash differs, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` contains `FIXED 2026-10-09 (SPEC-255)`. If absent, apply exactly as prototyped:
   - `reports/master/MASTER_GAP_REGISTER.md` from `979ae384bd92becba5a40a0bb52afc9e133efa5cddd67c0c9b0068e9cc27f985` to `d50b600224030eef28d59cca2389c300ca52e157244e1c3048892fd8ba96690c`
   - `reports/master/MASTER_EXECUTION_PLAN.md` from `29842fe769329d348688ed9586479f126e8696d75fcf3816528376a5cc5739d1` to `398457787054e2dce7f7edb59734cd8124cd0dc09ef29e2c3d8108f6e221abfb`

   If either holds bytes other than its "from" hash, or a resulting hash differs, stop.
4. **Check** for a `Local certification` Execution Log entry. If absent:
   - commit steps 1 to 3 with an Execution Log entry;
   - commit the Runtime Checkpoint as `Resume Step: DONE`;
   - run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` once, on the clean committed tree, and require `LOCAL_CERTIFY: READY`.

   No step runs any command that `-Finish` runs.
5. **Check** whether the manifest's `Last Completed` begins `**SPEC-255`. If not:
   - set it to this contract, with the Active pointer `None.`;
   - leave `Current Module`, `Next capability` (Batch 6 Slice 35) and the open-decision line unchanged;
   - keep the manifest within 7000 characters and 1200 per line;
   - regenerate `ai-map.json` with `scripts/generate-ai-map.ps1` and convert it to LF.

   Then Review, and Complete.

## Acceptance Criteria

- [ ] `scripts/check_agent_continuity.ps1` (`e40be2e7…`) compares frozen sections, Out of Scope, evidence prefixes and checklist wording ordinally, refuses a new prohibited character at the endpoint and per commit, and yields a boundary only when the declared value is an ancestor of the evaluated HEAD and equals the value first committed in `CR_LIFECYCLE.md`; otherwise the rule applies everywhere.
- [ ] `scripts/test_agent_continuity.ps1` (`c2ce82d8…`) carries CTRL4-1 to CTRL4-27, fifteen CTRL-4 mutants and the `CTRL4` population family, and passes in `-Finish`, including CTRL4-26 on this repository's history.
- [ ] CTRL4-24, CTRL4-25 and CTRL4-27 refuse both reproduced bypasses and the isolated first-declaration case, in CI's range shape with no pre-commit hook.
- [ ] `CR_LIFECYCLE.md` (`6b70b792…`) declares `Evidence Character Enforcement: ae1d130d82a1173099d858e667aab8dc88650d84`, states that the boundary cannot be moved, and both existing marker lines are byte-unchanged.
- [ ] `CODING_STANDARDS.md` (`847bc709…`) carries one added rule on exact comparison and deliberate text construction.
- [ ] The register (`d50b6002…`) records CTRL-4 fixed by this contract and CTRL-5, CTRL-6, CI-2, TEST-4, PERF-2, OPS-3 and OPS-4 open, each with owner and trigger; the execution plan (`39845778…`) names them without restating any status; `scripts/readiness_population.ps1` exits 0.
- [ ] SPEC-251, SPEC-252 and SPEC-254 stay Cancelled and are not modified by this contract, which modifies no other historical contract; SPEC-239's BEL is preserved.
- [ ] At Complete, the manifest names this contract, its `Next capability` is still Batch 6 Slice 35, its open-decision line is MAIL-1, RET-1 and PH8-10, and `ai-map.json` is regenerated LF.
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

**What changed from SPEC-254, and why.** Prototyped 2026-10-09 on `DESKTOP-0U3LC2V` (pwsh 7.6.6, 8 logical CPUs) in a scratch worktree from `33e4db6`.

- **Identity.** The allocator's own functions, run read-only at `33e4db6`, read the sequence cursor as 254 and found this identity unreserved, with no tracked mention. The Gate confirms it when this Draft is committed.
- **Criterion 9 is deleted without replacement.** SPEC identity belongs to `Validate-SpecAllocation`. A migration or database test would be a file outside Write Scope, which the last criterion already refuses. A claim about Primary is not local evidence (`SPEC-163`).
- **Criterion 1 is clarified, not changed.** `Get-CharacterBoundary` requires `merge-base --is-ancestor <declared> HEAD` and equality with the oldest `log -G` declaration in HEAD's history. CTRL4-27 and mutant M13 pin the ancestry precondition.
- **New evidence on these bytes:**
  - For both scripts, the token streams with comments removed are identical to SPEC-254's committed bytes. The six changed script lines are comments.
  - Repository consistency is CLEAN, `scripts/readiness_population.ps1` exits 0, `git diff --check` is clean, and no file holds a CR or a prohibited character.
  - All three marker lines equal `origin/main`'s, or SPEC-251's first declaration for the new one. `CODING_STANDARDS.md` is one line added and none removed against `origin/main`.
  - The full diff from SPEC-254's bytes is six files and 12 lines, all attribution text.
  - The Complete-state manifest fits: 355 characters remain for `Last Completed` within the 7000-character budget.
- **Carried evidence, valid because the behaviour is token-identical:**
  - SPEC-254's canonical `-Finish`, `LOCAL_CERTIFY: READY` in 40.1 min at `1149a2d`;
  - SPEC-252's full suite at 374 passed and 0 failed, the CTRL-4 block at 43/0 with populations 8, 19 and 15, the four guard self-tests, the pin negative on real history, and the 39-verdict historical replay.

  None of it replaces this contract's own `-Finish`, which Step 4 requires.
- **Separate engineering observation, recorded as CTRL-6 and not repaired.** `Read-GitFile` reads any git failure as "file absent". On Windows, a deep working directory plus a long `rev:path` fails with `Filename too long`, which made a local replay refuse two ranges that CI had accepted. It does not affect CI or this checkout.
