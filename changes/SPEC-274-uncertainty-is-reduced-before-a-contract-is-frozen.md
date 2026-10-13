# Change Request — SPEC-274

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Make it discoverable to every future ORVION agent, from the normal Boot path, that material uncertainty in a Draft is reduced in a disposable sandbox or prototype before Approval freezes it. Bound that practice so it never touches the authoritative repository, Primary or shared state, and never becomes a gate.

## Business Reason

Several recent contracts were cancelled or corrected for defects that were reproducible before approval:

- `SPEC-271` met a Supabase CLI regression only during execution.
- `SPEC-272`'s frozen scope could not publish its cancelled predecessor.
- `SPEC-251` lacked adversarial evidence.
- `SPEC-200`, `SPEC-252` and `SPEC-254` froze criteria that were false as written.

`SPEC-273` used a sandbox and a prototype and caught five defects before approval. The repository says nothing about this practice. `AGENTS.md` §1 tells a PLAN agent to "read, search, research, diagnose, and draft a proposed CR, but do not mutate implementation", which a fresh agent read as forbidding any execution. In a fresh-agent cold-start trial on 2026-10-13, the baseline agent called the question "ambiguous" and proposed no isolation. The owner ratified the principle on 2026-10-13: when uncertainty is material, agents consider safe isolated experiments and disposable prototypes before freezing a SPEC, risk-based and never mandatory.

## Risks

The change is governance prose only, with no executable control, gate, status or lifecycle change. It carries three risks:

- An agent could read the paragraph as a mandatory step and add cost to trivial contracts. The text says "risk-based, never mandatory" and names the typo and already-proven cases that need neither.
- An agent could treat a disposable clone's commits as reaching the authoritative repository. The text requires disabling the clone's push URL and forbids pushing, merging, promoting or certifying them.
- The guidance could become a second authority for §3's measurement rule. The text points to §3 rather than restating it.

No database, Primary, workflow or script is touched.

## Supersedes / Depends On

None

## Write Scope

- `AGENTS.md`
- `ENGINEERING_METHOD.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `PROJECT_CONTEXT.md`
- `CR_LIFECYCLE.md`
- `GOVERNANCE.md`
- `README.md`
- `CLAUDE.md`
- `changes/TEMPLATE.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/test_agent_continuity.ps1`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`

## Required Reading

- `AGENTS.md`
- `ENGINEERING_METHOD.md` §§2–3
- `CR_LIFECYCLE.md`
- `PROJECT_CONTEXT.md` §8

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github

## Additional Verification

None

## Pre-Approval Evidence

Change Class: Owner-Decision

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| The PLAN boundary in `AGENTS.md` §1 now names testing assumptions in a disposable sandbox or prototype outside the authoritative repository, and points to the method | Every cold-start agent via README, then Boot, then `AGENTS.md` | WRITE | Only one clause is inserted. "do not mutate implementation", the write-authority sentence and the status sentence are unchanged. Cold-start trials: Notes. |
| The same boundary | Boot's `WRITE_AUTHORITY: none (Draft CR authoring only)` line in `scripts/check_agent_continuity.ps1` | VERIFY | It describes authority over the repository. The new clause states that a disposable environment is outside it, so the script is not edited (Out of Scope). The second cold-start trial asked exactly this question and read it that way (Notes). |
| A new paragraph, "Reduce uncertainty before freezing", closes the `### Pre-Approval evidence sufficiency` rule in `ENGINEERING_METHOD.md` §2 | `changes/TEMPLATE.md`'s Pre-Approval Evidence comment, which already routes every Draft author to that rule; `CR_LIFECYCLE.md`'s SPEC-196 paragraph, which names it | VERIFY | Both already point to the rule by heading. The heading is unchanged and neither file is edited. |
| The same paragraph | `ENGINEERING_METHOD.md` §3, "Measure a verification before you freeze it as mandatory" | UNAFFECTED | It is referenced by name and not restated, so the measurement rule keeps one home (refinement 1). |
| The same paragraph | Repository consistency Check 26 (section pointers) and Check 27 (relocated owner-ratified anchors) | VERIFY | Rehearsal clone with both edits applied: `REPOSITORY CONSISTENCY: CLEAN`, "all 81 cross-document section pointers resolve". |
| "Isolated experiments" wording | `PROJECT_CONTEXT.md` §8 Non-Goals: "does not exist to create isolated experiments, temporary shortcuts, or architecture changes that bypass the canonical guidance" | VERIFY | It is a project non-goal qualified by "that bypass the canonical guidance", not an engineering prohibition. The paragraph's last sentence reconciles it from the method side, so `PROJECT_CONTEXT.md` is not edited (refinement 6). |
| Lifecycle, statuses, approval admissibility, every mandatory security and certification control | `CR_LIFECYCLE.md`, `scripts/check_agent_continuity.ps1`, the control suite | UNAFFECTED | No script, rule of admissibility, or gate changes. The practice is explicitly not authority and not a gate. |
| Manifest active pointer | Boot, Check 7, `scripts/generate-ai-map.ps1` | WRITE | `ai-map.json` and `repository-index.md` are in Write Scope. The rehearsal (Notes) measured which lifecycle commits change them; no other generated artifact changed. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Working tree is clean and the branch is not behind its upstream | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| The two implementation files equal their pinned target hashes and no other tracked path changed | BEFORE_COMPLETION | 1 | 2 | 3 |

## Implementation Steps

1. For each of the two files below, read its blob with `git hash-object --path=<path> <path>`. If it equals the `to` hash, record Already Applied. If it equals the `from` hash, make exactly the edit given in Notes ("Exact text"), so that its blob becomes exactly the `to` hash. Any other value means stop and report; do not guess.
   - `AGENTS.md`: from `3582ae173aed8a703eb4af127faa719fbf087a3b` to `b1d693e1b4e28ad7a7e5b29ba92460537747cc89`
   - `ENGINEERING_METHOD.md`: from `191eb68f29016a9be828a945530d93b8ad77ceff` to `b726938d67d9c1f151facce3e69c245179356620`
2. Check whether `git diff --name-only HEAD` lists only the two files above plus this contract. If so, record Already Applied. Otherwise stop and report any other path. Nothing else is edited in this step; the lifecycle commits own the manifest, `ai-map.json` and `repository-index.md`.
3. Check whether the Runtime Checkpoint already reads `Resume Step: DONE`. If so, record Already Applied. Otherwise synchronize the Execution Log and the Runtime Checkpoint to `DONE`, and commit the implementation and checkpoint together.
   - Then run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` normally.
   - If a check fails, preserve its exit code and evidence, and follow bounded recovery without weakening any assertion.

## Acceptance Criteria

- [x] `AGENTS.md` and `ENGINEERING_METHOD.md` each have exactly their Step 1 `to` blob.
- [x] `AGENTS.md` contains "Reduce uncertainty before freezing" exactly once, and `ENGINEERING_METHOD.md` contains "**Reduce uncertainty before freezing: sandbox and prototype" exactly once, placed before `## 3. Measurement integrity`.
- [x] `PROJECT_CONTEXT.md`, `CR_LIFECYCLE.md`, `changes/TEMPLATE.md` and every file under `scripts/` are byte-identical to the approval commit.
- [x] The tracked implementation diff touches only this contract's Write Scope.

## Execution Log

### 2026-10-13 — Claude

Outcome: Complete

Authority: the owner's 2026-10-13 authorization of Gate 1 and Gate 2 in advance, conditional on the exact Draft identity and passing Pre-Approval Evidence.
- Before approval, the Draft read blob `2a4b68470dd90580e3600aba2060fc008092868f` and SHA-256 `8f980beb408a3ed149547ef115f4fabe7093e7a35e1a0beb5b8fc76636f56b7b` on base `98fa06c`, and SPEC-274 was unreserved.
- The approval Gate returned `APPROVAL_EVIDENCE: PASS`.
- A targeted read-only cold-start check on the final text, held for the two late wording fixes, read both as intended: a `git worktree` is refused in favour of a fresh clone with push disabled, and §3 is unchanged.

Step results:
- Step 1: Applied. Each file was at its `from` hash, and the edit in Notes ("Exact text") was made. `git hash-object --path` then read exactly the `to` hashes:
  - `AGENTS.md`: `3582ae17` to `b1d693e1`
  - `ENGINEERING_METHOD.md`: `191eb68f` to `b726938d`
- Step 2: Applied. `git diff --name-only HEAD` listed exactly `AGENTS.md` and `ENGINEERING_METHOD.md`; no other path changed.
- Step 3: Applied. The Runtime Checkpoint is synchronized to `DONE` and committed with the implementation. `-Finish` runs next, normally.

Commits: the implementation and checkpoint commit that carries this entry.

## Verification Notes

### 2026-10-13 — Claude (Independent Review of `341fcbd`)

Verdict: Confirmed Complete

Findings: re-checked against the committed repository after `-Finish`, not against the Execution Log.

1. **Criterion 1.** At HEAD, `AGENTS.md` reads `b1d693e1` and `ENGINEERING_METHOD.md` reads `b726938d`, exactly their pinned blobs.
2. **Criterion 2.** "Reduce uncertainty before freezing" occurs once in `AGENTS.md`. "**Reduce uncertainty before freezing: sandbox and prototype" occurs once in `ENGINEERING_METHOD.md`, before `## 3. Measurement integrity`.
3. **Criterion 3.** `git diff --quiet 24127e8 HEAD` is clean for `PROJECT_CONTEXT.md`, `CR_LIFECYCLE.md`, `changes/TEMPLATE.md` and `scripts/`.
4. **Criterion 4.** `git diff --name-only 98fa06c HEAD` lists `AGENTS.md`, `ENGINEERING_METHOD.md`, `_ORVION_CANONICAL/manifest.md`, `ai-map.json` and this contract, all inside Write Scope. `repository-index.md` is in scope and reproduces unchanged.
5. **Local certification.** `-Finish` at `341fcbd` ran normally (`concurrent=statusline.ps1` at start, `concurrent_end=0`). Every command passed: `test_agent_continuity.ps1` (21.4 min), `test_cold_start_state_guard.ps1`, `test_status_contradiction_guard.ps1`, `test_primary_ledger_guard.ps1`, `test_future_date_guard.ps1`, `check_repository_consistency.ps1`, and `git diff --check`. The result was `LOCAL_CERTIFY: READY`, `END exit=0 total=31.2 min`. The receipt names SPEC-274, READY, profiles CONTROL and REPOSITORY.
6. **Boundaries.**
   - SPEC-271, SPEC-272 and SPEC-273 are byte-identical to `98fa06c`.
   - No script, gate, lifecycle state, workflow, Primary or production system was touched.
   - `PROJECT_CONTEXT.md`, `README.md` and Boot are unchanged.
   - The guidance is risk-based, adds no mandatory step, and points to §3 without restating it.

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

- **Owner authority.** On 2026-10-13 the owner approved drafting this contract and ratified the principle, with nine refinements. Each refinement maps to the text as follows:
  - 1, one authority, no gate: §3 is referenced, not restated, and nothing becomes a gate.
  - 2, disposable versus authoritative: "Changing a disposable environment is not a write to the repository".
  - 3, temporary commits in a disposable clone: allowed, with the push URL disabled; never pushed, merged, promoted or certified.
  - 4, protected targets: the working tree and its Git refs, Primary, production, existing local databases, shared containers, credentials, other agents' work.
  - 5, optional: "risk-based, never mandatory" and "a typo or an already-proven deterministic correction needs neither".
  - 6, contradictory wording: the Consumer Closure rows for `PROJECT_CONTEXT.md` §8 and Boot's `WRITE_AUTHORITY` line.
  - 7, cold-start evidence: below, stated as qualitative.
  - 8, discoverable from Boot: the README → Boot → `AGENTS.md` §1 pointer.
  - 9, generated artifacts: the rehearsal below.
- **Exact text.**
  - In `AGENTS.md` §1, the sentence "In PLAN, read, search, research, diagnose, and draft a proposed CR, but do not mutate implementation." becomes the line in the first block below.
  - In `ENGINEERING_METHOD.md`, the paragraph and bullets in the second block are inserted between the paragraph ending "so retiring one needs no edit." and the `## 3. Measurement integrity` separator, with one blank line on each side.
  - Files are LF, UTF-8 without BOM.

```text
In PLAN, read, search, research, diagnose, test assumptions in a disposable sandbox or prototype outside the authoritative repository (`ENGINEERING_METHOD.md §2`, "Reduce uncertainty before freezing"), and draft a proposed CR, but do not mutate implementation.
```

```text
**Reduce uncertainty before freezing: sandbox and prototype (2026-10-13, owner directive).** Approval freezes authority, so when uncertainty about a Draft is material, test the design before approval rather than discover a preventable defect while executing it. This is risk-based, never mandatory. A *sandbox* is an isolated, disposable environment, such as a scratch directory, a fresh clone (not a `git worktree`, which shares the repository's refs and config), a separate local Supabase project id and ports, a throwaway container, or the control suite's own sandbox bootstrap. It is used to reproduce a defect, compare alternatives, or test an assumption about runtime, database, CI or governance behaviour. A *prototype* is the smallest disposable version of the intended change, run in a sandbox. It shows whether the repair works, exercises its positive and negative cases, and reveals the exact files, consumers and blockers, so that the Draft's Write Scope, steps, criteria and Pre-Approval Evidence are written from observation rather than prediction. Three rehearsals cover the failures that cancelled recent contracts:
  - run the pinned toolchain against a disposable project and the affected suites (`SPEC-271` met a CLI regression only at execution);
  - commit the Draft's whole lifecycle in a disposable clone and run `-Gate -BaseRef origin/main` over the future publication range (`SPEC-272`'s scope could not publish its cancelled predecessor);
  - check each Acceptance Criterion and the approval transition against the prototype's actual result (`SPEC-200`, `SPEC-252` and `SPEC-254` froze criteria that were false as written).

  Use them only when they cost less than a failed contract; a typo or an already-proven deterministic correction needs neither. Changing a disposable environment is not a write to the repository, and it confers no authority. A disposable clone may hold temporary commits when range, CI or lifecycle behaviour cannot be reproduced otherwise. Disable its push URL first (`git remote set-url --push origin none`): those commits are never pushed, merged or promoted, and never count as certified implementation. A sandbox never touches the authoritative working tree or its Git refs, Primary, production systems, existing local databases, shared containers, credentials, or other agents' work. Measuring the commands a contract will be judged by remains §3's rule ("Measure a verification before you freeze it as mandatory"), unchanged; where running one would disturb shared state, a sandbox lets an author run it in isolation. A prototype informs the contract and never replaces its frozen verification. `PROJECT_CONTEXT.md` §8 excludes experiments that bypass the canonical guidance; this one serves a contract under it.
```

- **Cold-start evidence (qualitative, not statistically conclusive).** Each trial is one fresh agent with no chat history, started from README.
  - 2026-10-13 A/B pair on an earlier wording, in two disposable clones. The baseline agent, on the unchanged repository, called the pre-approval question "ambiguous" and proposed no isolation. The proposal agent found the guidance through README, Boot, `AGENTS.md` and `ENGINEERING_METHOD.md`, applied it, and correctly declined it for a typo.
  - 2026-10-13, a second trial on the near-final text, run read-only in the rehearsal clone, answering four questions with file and line citations. The agent took the path README → Boot → `AGENTS.md` §1 → `ENGINEERING_METHOD.md` §2 and answered all four as intended:
    - for a range-Gate change with a cancelled predecessor, it chose the whole-lifecycle clone rehearsal, with commits allowed only in a disposable clone whose push URL is disabled;
    - for a typo, it chose none;
    - it read Boot's `WRITE_AUTHORITY` line and `PROJECT_CONTEXT.md` §8 as not forbidding a throwaway Supabase project;
    - it refused the existing local stack, Primary and the authoritative working tree.
  - The second trial raised two points of genuine ambiguity, and the text above settles both:
    - a `git worktree` shares the repository's refs and config, so it is not a disposable environment;
    - "without a shared stack" could be read as narrowing §3, so §3 is now stated to be unchanged, with a sandbox used only where a command would disturb shared state.

    The text also now names the command that disables pushing.
  - The trial's other observations are left deliberately:
    - "Material" has no numeric threshold, because the practice is risk-based by the owner's decision.
    - `PROJECT_CONTEXT.md` §8, read alone, still says "isolated experiments"; see below.
    - Boot's line does not mention sandboxes, and editing it would change the control plane for a wording the `AGENTS.md` clause already settles.
  - Three single agents show discoverability and correct reading, not a rate.
- **Why no executable check.** A guard would have to judge whether uncertainty was "material", which is not mechanically decidable. Making the practice a gate would contradict the owner's "risk-based, not mandatory". Discoverability is what the cold-start trials measure.
- **Why `PROJECT_CONTEXT.md` is not edited.** Its §8 non-goal is qualified by "that bypass the canonical guidance". One sentence on the method side settles the reading at lower cost than a third file.
- **Rehearsal (refinement 9, and §3's measurement rule).** Done 2026-10-13 in a disposable clone of `98fa06c`. Its push URL was set to `none`, and a dry-run push was refused (`'none' does not appear to be a git repository`). Nothing was pushed; the authoritative tree, its refs, Docker and every database were untouched.
  - The whole lifecycle was committed in the clone (Draft, Approve, Begin, Implement, Complete) on a near-final copy of this contract that differed only in these Notes.
    - At Draft, the Gate read `READY / PLAN`.
    - At Approve, it read `APPROVAL_EVIDENCE: PASS` and `VERIFICATION: CONTROL, REPOSITORY`.
    - At Begin it read `EXECUTE`, and at Implement `VERIFY / STEP: DONE`.
  - At Implement, `git hash-object --path` read exactly the two `to` blobs.
  - `-Finish` at the Implement commit ran every mandatory command, with nothing else running. Each passed: `test_agent_continuity.ps1` (22.7 min), `test_cold_start_state_guard.ps1`, `test_status_contradiction_guard.ps1`, `test_primary_ledger_guard.ps1`, `test_future_date_guard.ps1`, `check_repository_consistency.ps1` and `git diff --check`. The result was `LOCAL_CERTIFY: READY`, `END exit=0 total=32.7 min concurrent_end=0`. The receipt names SPEC-274, READY, profiles CONTROL and REPOSITORY.
  - After Complete, `-Gate -BaseRef origin/main` over the five commits read `READY / VERIFY / SPEC-274 / Complete`, `REPOSITORY: clean`, exit 0. The net diff is exactly `AGENTS.md`, `ENGINEERING_METHOD.md` and this contract.
  - Write Scope closure:
    - Approve and Complete change `_ORVION_CANONICAL/manifest.md` and `ai-map.json` (and return them to baseline).
    - `repository-index.md` reproduced unchanged at every stage. It stays in scope because `scripts/generate-ai-map.ps1` owns both artifacts, following the `SPEC-273` precedent.
    - No other path was written.
  - The rehearsal also caught one defect before freezing. An `Additional Verification` body of `None.` fails the parser (`INVALID_ADDITIONAL_VERIFICATION:None.`); only `None` is accepted, which the Draft now uses.
