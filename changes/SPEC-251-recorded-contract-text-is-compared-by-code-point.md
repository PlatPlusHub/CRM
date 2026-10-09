# Change Request — SPEC-251

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make approved and recorded contract text resistant to invisible, case-only and Unicode-equivalence mutations: compare frozen sections, Out of Scope, append-only evidence and checklist wording by code point, and refuse any new invisible or control character in a governed contract from a declared forward-only boundary, preserving every historical record.

## Business Reason

- **The owner's decision (2026-10-09, SPEC-251 scope approved in principle):** cover all four demonstrated comparison surfaces; add one short coding-standard rule; preserve historical evidence, including SPEC-239's BEL; use a verified forward-only boundary where necessary; prove both directions with causal mutation tests; register other proven findings only in their existing home; then return directly to Batch 6 Slice 35.
- **Earned evidence (the manifest's reopening condition):**
  - **Incident.** A PowerShell expanding string committed a NUL and a backspace into SPEC-250's Begin entry. Repository consistency reported CLEAN, the Gate passed, and the NUL made the file invisible to every recursive search until the owner-authorized reconstruction removed it before publication.
  - **Recurrence.** Published SPEC-239 carries a BEL from the same escape (`` `a``), unnoticed since its Draft `7264c98`.
  - **Proven safety gap.** On the evaluator at `ae1d130`, fourteen attacks on frozen or recorded text were admitted with `ORVION: READY` (Notes). PowerShell's `-ne`, `-cne` and a bare `StartsWith(string)` compare by culture: they ignore case (`-ne`), treat NUL, backspace, zero-width space and soft hyphen as absent, and call a composed and a decomposed letter equal.

## Risks

- **A legitimate contract could be newly refused.** Excluded by measurement: the real Gate over the thirteen publication ranges `73e571c..ae1d130` gives the same verdict under both evaluators once the boundary is declared, and seven MUST-ACCEPT cases pin TAB, symbols, an emoji variation selector, accents, multiline entries, a CRLF working copy, unchanged non-ASCII history, a checkbox move and a historical BEL.
- **Normalization semantics.** `Normalize` (CRLF to LF, outer trim) and `EvidenceBody` are unchanged; only the comparison after them becomes ordinal.
- **History.** No contract is rewritten. The character rule counts against the baseline, so text already in history is preserved, and it is forward-only from `ae1d130`, so SPEC-239's published range keeps its verdict. Without the boundary that range turns into `PROHIBITED_CHARACTER:U+0007`, which is why the boundary exists.
- **Fail-closed reading.** A missing marker, or a boundary a clone does not contain, reads as active, the same principle as CTRL-1.
- **CONTROL text.** `CR_LIFECYCLE.md` gains one paragraph and one marker line after the CTRL-1 marker; the two existing marker lines stay byte-identical. `CODING_STANDARDS.md §12` gains one rule.
- **No Primary access, migration or database test.** No later SPEC identity is named.

## Supersedes / Depends On

None. SPEC-239 and SPEC-250 are Complete and are not modified.

## Write Scope

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

- `CR_LIFECYCLE.md` §4, §8 and the three declared-marker paragraphs; `CODING_STANDARDS.md §12`
- `scripts/check_agent_continuity.ps1`: `Normalize`, `EvidenceBody`, `Validate-FrozenAuthority`, `Validate-EvidenceAppendOnly`, `Validate-Checklist`, `Historical-Guard-IsActive`, `Validate-CommittedRange` and the endpoint block
- `scripts/test_agent_continuity.ps1`: `MutationKill`, `MutationKillRangeAt`, `Pop` and the NON-EMPTY POPULATIONS loop
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
| `Validate-FrozenAuthority`, `Validate-EvidenceAppendOnly` and `Validate-Checklist` compare ordinally (`Same-Text`, `StartsWith(..., Ordinal)`) | Every Gate: the pre-commit hook, `-Finish`, Agent Control and ORVION Acceptance (`-Gate -BaseRef`); every governed contract | WRITE | `Normalize` and `EvidenceBody` unchanged. CTRL4-1 to CTRL4-7 refuse, and each was admitted by the `ae1d130` evaluator. Existing cases 23 to 60 pass unchanged. |
| `Validate-NoNewProhibitedCharacter`, at the endpoint and per commit in `Validate-CommittedRange` | Every governed contract; SPEC-239's historical BEL; CRLF working copies; emoji presentation selectors | WRITE | CTRL4-8 to CTRL4-14 refuse; CTRL4-15 to CTRL4-20 accept. The regex is ASCII-escaped and was proven equivalent to the prototype's over every BMP code point in three contexts. |
| `Character-Guard-IsActive` and the `Evidence Character Enforcement` marker in `CR_LIFECYCLE.md` | The Gate reads it from the working tree, as CTRL-1's; the existing `SPEC Allocation Enforcement` and `Historical CR Immutability Enforcement` lines; the suite's fixture lifecycle file, which carries no new marker and therefore reads active | WRITE | CTRL4-21 accepts a character added before a declared boundary; CTRL4-22 refuses one added after it; CTRL4-23 protects on an unknown boundary. The two existing marker lines are byte-unchanged. |
| `scripts/test_agent_continuity.ps1`: CTRL4-1 to CTRL4-23, fourteen CTRL-4 mutants, family `CTRL4` in NON-EMPTY POPULATIONS | Agent Control and ORVION Acceptance CI; `-Finish` (CONTROL) | WRITE | Final prototype: `AGENT CONTROL TESTS: 369 passed, 0 failed` (31.8 min, under concurrent load). |
| Historical publication ranges on `origin/main` | CI or anyone replaying a published range with the new evaluator | VERIFY | Thirteen ranges `73e571c..ae1d130`, real `-Gate -BaseRef -HeadRef`, Notes. |
| `CODING_STANDARDS.md §12`: one rule | Authors; no parser | WRITE | One bullet inserted before the `$Matches` trap; nothing existing changes. |
| `MASTER_GAP_REGISTER.md`: CTRL-4 settled; CTRL-5, CI-2, TEST-4, PERF-2, OPS-3, OPS-4 open | Checks 2, 11, 14, 21 and 25; `scripts/readiness_population.ps1`; `test_cold_start_state_guard.ps1`'s open-decision pin | WRITE | Owner Decision is `—` on every row, so Check 25 and the pin read no new decision. Repository consistency CLEAN on the prototype. |
| `MASTER_EXECUTION_PLAN.md`: the six open ids join the gate's control-plane residuals | `scripts/readiness_population.ps1` (every open id must be named) | WRITE | Prototype: 454 ids, 325 settled, `every derived finding and decision id is named in the gate section`, exit 0. |
| Manifest `Last Completed` and Active pointer; `ai-map.json` | Checks 5 and 7; Boot; `test_cold_start_state_guard.ps1` | WRITE | `Next capability` (Batch 6 Slice 35) and the open-decision line (MAIL-1, RET-1, PH8-10) are unchanged. The four guard self-tests on the prototype: 34/0, 33/0, 13/0, 18/0. |

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
- `Validate-FrozenAuthority`, `Validate-EvidenceAppendOnly` and `Validate-Checklist`, unchanged except for the comparison.
- `Validate-CommittedRange`'s per-commit walk, where the parent text is already read.
- CTRL-1's declared-boundary pattern: a marker line in `CR_LIFECYCLE.md`, read from the working tree through `$script:HistoricalAuthority`, decided by Git ancestry, unprovable meaning protect.
- The suite's `MutationKill`, `MutationKillRangeAt`, `Pop` and NON-EMPTY POPULATIONS.

Nothing else is added: no mode, switch, file, workflow or capability. Rejected: normalizing text before comparison or NFC (either would make re-encoding legal); refusing all non-ASCII (it would refuse the em-dashes and symbols in hundreds of contracts); a retroactive rule (SPEC-239's range flips); any general mechanism for editing evidence (owner prohibited).

Added Property: Frozen sections, Out of Scope, Execution Log and Verification Notes prefixes, and Acceptance Criteria and Review Gate wording are equal only when their code points are equal after the existing CRLF and trim normalization. A governed contract may not gain a C0 control other than TAB, LF and a CRLF's CR, a DEL or C1 control, or an invisible format character; the count is judged against the baseline at the endpoint and against the parent at every committed state whose parent descends from `ae1d130`.

Causal Negative: On the evaluator at `ae1d130`, CTRL4-1 to CTRL4-14 each returned `ORVION: READY` with `MODE: EXECUTE`: the re-encodings in the Execution Log and in Verification Notes, the deleted NUL, the four case-only edits, the NUL, backspace, BEL, zero-width space and soft hyphen entering a contract, the zero-width space entering a frozen section, and the NUL added and removed inside one range. The six MUST-ACCEPT cases then present passed there too.

Positive Test Design: CTRL4-15 TAB, symbols, an emoji variation selector and accents; CTRL4-16 a multiline entry with a code fence appended after multiline evidence; CTRL4-17 unchanged non-ASCII evidence reads back identically and appends; CTRL4-18 a CRLF working copy of an LF contract appends; CTRL4-19 checking non-ASCII criteria with unchanged wording; CTRL4-20 a BEL already in published history is preserved and clean evidence appends; CTRL4-21 a character added before the declared boundary keeps its verdict. Existing cases 23 to 60 pass unchanged.

Negative Test Design: CTRL4-1 to CTRL4-7 refuse with `EVIDENCE_NOT_APPEND_ONLY`, `ACCEPTANCE_TEXT_MUTATED`, `REVIEW_GATE_TEXT_MUTATED` or `FROZEN_AUTHORITY_MUTATED`; CTRL4-8 to CTRL4-14, CTRL4-22 and CTRL4-23 refuse with `PROHIBITED_CHARACTER` naming the code point. Each ordinal case uses an edit the character rule cannot see, so its refusal is credited to the comparison alone.

Non-Empty Population Obligation: Family `CTRL4` carries 7 accepting cases, 16 refusing cases and 14 mutation kills, asserted by `NON-EMPTY POPULATION CTRL4`. The replay population is every publication range between consecutive Complete commits from SPEC-237 to SPEC-250.

Mutation Obligation: Each mutant is applied to a committed sandbox copy of the evaluator by the suite's own harness, which asserts the find string was present, the pristine run shows the expected evidence and the mutated run does not. A mutant whose application is not proven is a harness error, never a kill.

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
| M13 | an unknown boundary reads inactive | the unknown-boundary range |
| M14 | a missing marker reads inactive | the add-and-remove range |

Prototype result: all fourteen applied and killed (`PASS CTRL-4 MUTATION: …`, 14 of 14) in the CTRL-4 block's own run and again in the full suite.

Post-Implementation Proof Obligation: On the final committed bytes, canonical `-Finish` (CONTROL and REPOSITORY: agent continuity with every CTRL-4 case and mutant, the four guard self-tests, repository consistency, and `scripts/readiness_population.ps1`), then `-Gate -BaseRef origin/main`, candidate CI, `main` CI after exact-SHA promotion, and `-Certify`.

## Implementation Steps

Every file is written LF. Each SHA-256 below was measured on the prototype at `ae1d130`.

1. **Check** whether `scripts/check_agent_continuity.ps1` contains `function Character-Guard-IsActive`. If absent, write the evaluator and its suite exactly as prototyped:
   - `scripts/check_agent_continuity.ps1` `21fa36ab7aeda9b7a69898d4253c76a52e854758a83e67fde66a44dd4bd0d06e`
   - `scripts/test_agent_continuity.ps1` `7abb8a46b1fd765214fffcef8866431e4a97142e910357a520d80bf566195735`

   If either holds other content, or a resulting hash differs, stop.
2. **Check** whether `CR_LIFECYCLE.md` contains `Evidence Character Enforcement:`. If absent, apply exactly as prototyped:
   - `CR_LIFECYCLE.md`: the CTRL-4 paragraph and marker line directly after `Historical CR Immutability Enforcement: 5d78aacd5335278c5b03edb0b3f969bd86e6b9c4`. Expected `3ba1d297ce3be8ded26d7641f2a75f0b59e8bca9583667fd5dbbc4bac8eb2a3a`.
   - `CODING_STANDARDS.md`: the rule "Integrity checks compare exactly, and text is built deliberately", before the `$Matches` trap. Expected `066e36bf98c3e2f440d3cf504395a60a9d3ea4f5ce283b71c39917b09b037a42`.

   If a target holds other content, or a resulting hash differs, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` contains `| CTRL-4 |`. If absent, apply exactly as prototyped:
   - the register: CTRL-4, CTRL-5, CI-2, TEST-4, PERF-2, OPS-3 and OPS-4 after SUB-5. Expected `f0c0e5e37b5a07f15d271d1e916155dae80239a6a01034c49ce0c4ee2e21eb12`.
   - `reports/master/MASTER_EXECUTION_PLAN.md`: the six open ids join the control-plane residuals bullet. Expected `736cf8c6db526e12aab74dabc4d3565cd473a5b60b440bdee4bb4890483039e1`.

   If a target holds other content, or a resulting hash differs, stop.
4. **Check** for a `Local certification` Execution Log entry. If absent:
   - commit steps 1 to 3 with an Execution Log entry;
   - commit the Runtime Checkpoint as `Resume Step: DONE`;
   - run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` once, on the clean committed tree, and require `LOCAL_CERTIFY: READY`.

   No step runs any command that `-Finish` runs.
5. **Check** whether the manifest's `Last Completed` begins `**SPEC-251`. If not:
   - set it to this contract, with the Active pointer `None.`;
   - leave `Current Module`, `Next capability` (Batch 6 Slice 35) and the open-decision line unchanged;
   - keep the manifest within 7000 characters and 1200 per line;
   - regenerate `ai-map.json` with `scripts/generate-ai-map.ps1` and convert it to LF.

   Then Review, and Complete.

## Acceptance Criteria

- [ ] `scripts/check_agent_continuity.ps1` (`21fa36ab…`) compares frozen sections, Out of Scope, evidence prefixes and checklist wording ordinally, and refuses a new prohibited character at the endpoint and per commit, forward-only from the declared boundary.
- [ ] `scripts/test_agent_continuity.ps1` (`7abb8a46…`) carries CTRL4-1 to CTRL4-23, fourteen CTRL-4 mutants and the `CTRL4` population family, and passes in `-Finish`.
- [ ] `CR_LIFECYCLE.md` (`3ba1d297…`) declares `Evidence Character Enforcement: ae1d130d82a1173099d858e667aab8dc88650d84`, and both existing marker lines are byte-unchanged.
- [ ] `CODING_STANDARDS.md` (`066e36bf…`) carries one added rule on exact comparison and deliberate text construction.
- [ ] The register (`f0c0e5e3…`) records CTRL-4 fixed and CTRL-5, CI-2, TEST-4, PERF-2, OPS-3 and OPS-4 open, each with owner and trigger; the execution plan (`736cf8c6…`) classifies them; `scripts/readiness_population.ps1` exits 0.
- [ ] No historical contract is modified; SPEC-239's BEL is preserved.
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

**Prototype evidence**, measured 2026-10-09 in scratch worktrees at `ae1d130` on `DESKTOP-0U3LC2V` (pwsh 7.6.6, 8 logical CPUs). Every figure was copied from the run's own output.

- **Baseline behaviour, measured before attributing anything to comparison semantics.** The CTRL-4 block alone, on the `ae1d130` evaluator: all fourteen refusal cases failed, and in each the Gate printed `ORVION: READY` and `MODE: EXECUTE`, an acceptance and not a refusal for another reason. Attribution: CTRL4-1 to CTRL4-7 are comparison semantics (case, normalization, an ignorable deletion); CTRL4-8 to CTRL4-12 and CTRL4-14 had no rule at all; CTRL4-13 is both. The six MUST-ACCEPT cases passed there too.
- **The CTRL-4 block on the prototype:** 38 passed, 0 failed, with populations accept 7, reject 16, mutation 14.
- **The full suite on the final bytes:** `AGENT CONTROL TESTS: 369 passed, 0 failed` in 31.8 min, run beside two replays.
- **The four guard self-tests:** cold-start 34/0, status contradiction 33/0, Primary ledger 13/0, future date 18/0, in 13.0 min.
- **Repository consistency:** CLEAN. **Readiness population:** 454 ids, 325 settled, every id classified, exit 0.
- **Historical replay, end to end.** The real Gate (`-Gate -Root <worktree at head> -BaseRef <previous Complete> -HeadRef <Complete>`) over the thirteen ranges from `73e571c` to `ae1d130`:
  - Old evaluator and new evaluator without the marker: 12 identical verdicts; `2496591..6c48fbb` (SPEC-239) is READY under the old one and `PROHIBITED_CHARACTER:U+0007` under the new one.
  - New evaluator with the marker declared: all 13 verdicts equal the old evaluator's. SPEC-239's range is READY.
  - Two ranges, `bdf6f1b..523888d` (SPEC-247) and `f70e1b3..ae1d130` (SPEC-250), are refused `INVALID_COMPLETION_TRANSITION` by the old evaluator and the new one alike. Both contracts' traced status paths are `Draft, Approved, In Progress, …, Complete`, and both publications were accepted by CI and remotely certified. The refusal is a property of this local replay, present before SPEC-251, and is not investigated here.
- **Defects found while prototyping, and fixed before freezing:**
  - The prototype regex held literal invisible characters (soft hyphen, zero-width space, BOM, bidirectional controls), because a Unicode escape written through the agent's file tool arrived as the character itself. It is now ASCII escapes, proven equivalent.
  - Two mutants first reported `applied=False` for the same reason; the harness's own assertion caught it, and the find strings were escaped.
  - Without a boundary, the replay showed SPEC-239's published range would flip; the forward-only boundary is the measured answer, not a precaution.
- **The empty Write Scope.** The false PASS seen on 2026-10-09 came from an unsupported line-range invocation with a misnamed property. The production Gate cannot reach the evaluator with an empty Write Scope (`Contract` throws `EMPTY_WRITE_SCOPE`). It is recorded as CTRL-5, a tooling gap, and is not repaired here.
