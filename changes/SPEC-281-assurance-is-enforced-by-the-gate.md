# Change Request — SPEC-281

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Make the existing Gate enforce four assurance responsibilities without relying on any agent reading guidance: CI re-proves every contract transition the hook judges, a manifest line that names its owner keeps its ratified text, an authority change closes the consumers the Gate derives, and a criterion's `check:` must be satisfiable at Approval and true at Complete. A `-Trusted` Gate mode and an owner promotion script, `scripts/promote_main.ps1`, are also added: the owner can judge a candidate without executing it, and push only the SHA that was judged.

## Business Reason

- **CI did not re-prove what the hook proves (CTRL-17).** Measured at `e110626` in a push-disabled clone, four ranges whose defective commit skipped the hook with `git commit --no-verify` were each refused by the hook and READY under `-Gate -BaseRef`, which `orvion-acceptance` runs:
  - a criterion reworded after Approval (`ACCEPTANCE_TEXT_MUTATED`);
  - a Review Gate item reworded after Approval (`REVIEW_GATE_TEXT_MUTATED`);
  - a `Complete` with three unticked criteria and no verdict (`COMPLETION_PREREQUISITE`);
  - a rewritten Execution Log (`EVIDENCE_NOT_APPEND_ONLY`).

  One cause covers all four. `SPEC-167` judged recorded text and completion prerequisites at `HEAD`, against the contract as it stood at the range base. A Draft is committed only at Approval, so every contract is born inside the range that publishes it and has no base copy to compare against. `CR_LIFECYCLE.md` §8 says CI re-proves these properties, so that statement was false.
- **Approval admitted a contract that contradicted current authority (CTRL-18).** `SPEC-278` copied `SPEC-268`'s Consumer Closure, Step 10 and criteria after `SPEC-270` had made `Next capability` point at its owner instead of holding a copied target. Its Consumer Closure declared WRITE on `Current Module` and `Next capability`. The evaluator replayed its Approval as PASS, and the contradiction surfaced only after the Primary deployment, which cost a cancellation and a successor. Applying its Steps 9 and 10 leaves repository consistency CLEAN. No check reads what a line means, and the line's own rule, "never a copy of it here", was prose.
- **A candidate certifies itself (CTRL-19).**
  - `main` requires `orvion-acceptance`. That check runs the candidate's own workflow and evaluator, and GitHub counts a `skipped` or `neutral` required check as passing (official documentation, 2026-10-14).
  - In this contract's prototype, a candidate that neutered its own evaluator was READY under it.
  - The agent's GitHub credential is the owner's, with repository administration (`gh api`: `admin: true`), so it could also change Ruleset 22950574.
  - None of this can be repaired inside the repository. This contract adds the repository half, `-Gate -Trusted` and `scripts/promote_main.ps1`, and registers the owner's half.
- **Worth it.**
  - The 19 cancellations since `SPEC-169` are dominated by frozen contracts that execution then proved wrong.
  - 35 of 78 Batch 6 surfaces remain, and each slice Draft is likely to start from the previous one.
  - The added checks run inside the Gate the hook and CI already run. They add no workflow, service or credential.

## Risks

- **False refusals.**
  - Replaying the last 12 ranges `main` published (`SPEC-265` to `SPEC-280`), the new evaluator returned the same verdict as `e110626`'s on every one. Nine are READY, `SPEC-278`'s cancellation and `SPEC-279`'s successor included; the three oldest are refused by both for a write closure `SPEC-270` added later.
  - The existing control suite passed 444 of 446 against the prototype evaluator. The 2 failures were mutation cases whose target moved into the shared functions, and they are retargeted here. With the new cases, the suite passed 492 of 492 before the promotion script was added; this contract's `-Finish` reruns the whole suite on these exact bytes.
- **A blocked lawful change.** Changing a pinned line stays lawful: test 281-A4 publishes a line, its pin and its consumers together. A step that only reads a pinned line declares `UNAFFECTED` (281-S6); `SPEC-279`'s Consumer Closure already did.
- **Cost.** Measured figures are recorded in Notes. `-Finish` of this contract runs the five CONTROL suites.
- **Not closed by this contract.** CTRL-19 stays open until the owner changes GitHub configuration (Notes), and this contract claims no trusted publication path before then. Whether a declared disposition is true, and whether a criterion with no check is met, remain Review judgment.
- No migration, schema, Primary or Secondary action, and no Batch 6 slice.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-281-assurance-is-enforced-by-the-gate.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/promote_main.ps1`
- `GOVERNANCE.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `changes/TEMPLATE.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `AGENTS.md`
- `README.md`
- `CODING_STANDARDS.md`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/impact.ps1`
- `scripts/publish_candidate.ps1`
- `scripts/readiness_population.ps1`
- `.githooks/pre-commit`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/agent-control.yml`
- `reports/master/MASTER_REPOSITORY_HEALTH.md`
- `reports/future-backlog.md`
- `changes/SPEC-270-the-repository-reconciles-what-it-can-derive.md`
- `changes/SPEC-278-a-used-ledger-account-keeps-its-meaning.md`
- `changes/SPEC-279-the-ledger-account-slice-is-closed-and-published.md`
- `changes/SPEC-280-the-ledger-slices-follow-ups-reach-their-owners.md`

## Required Reading

- `CR_LIFECYCLE.md` §8 (the mechanically enforced partition; `SPEC-167`; `SPEC-273`)
- `ENGINEERING_METHOD.md` §2 (Pre-Approval evidence sufficiency)
- `GOVERNANCE.md` §2 and §6
- `changes/SPEC-278-a-used-ledger-account-keeps-its-meaning.md` (Consumer Closure, Step 10, Acceptance Criteria)
- `changes/SPEC-270-the-repository-reconciles-what-it-can-derive.md` (Consumer Closure)

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
| A range re-proves every transition of its governing contract at the commit that made it | `orvion-acceptance` and Agent Control, which run `-Gate -BaseRef`; `scripts/publish_candidate.ps1`, which proves the committed range first; every later publication | WRITE | The four `--no-verify` ranges are refused with the code and the offending commit after `@` (281-P1…P4); a lawful lifecycle is READY (281-P5); the last 12 published ranges keep their verdicts; `SPEC-273` segments and cancellations are unchanged (`SPEC-279`'s range READY). |
| The hook and the walk share one definition of a transition | `scripts/check_agent_continuity.ps1`, and the RANGE-AUTHORITY cases of `scripts/test_agent_continuity.ps1` | WRITE | Two mutation cases retargeted to the shared functions; every other existing case unchanged. |
| The manifest lines `Current Module`, `Batch 6 surface coverage` and `Next capability` are pinned by `GOVERNANCE.md` §6 | `CR_LIFECYCLE.md` §9, whose `Complete` command rewrote `Current Module` and `Next capability` | WRITE | §9 now rewrites them only when they name a package, so completion never touches a pinned line. |
| The same pinned lines | `scripts/generate-ai-map.ps1` and `scripts/check_repository_consistency.ps1` (Checks 5, 6, 7 and 16), which read them | UNAFFECTED | Line text unchanged; Check 7 reproduces both projections (prototype consistency CLEAN). |
| The same pinned lines | `scripts/check_agent_continuity.ps1` (`Manifest` reads `Next capability` for Boot) | WRITE | The pins are enforced here; Boot's `NEXT_CAPABILITY` output is unchanged. |
| The same pinned lines | `scripts/test_agent_continuity.ps1`, whose fixture manifest has its own `Next capability` line | WRITE | Fixtures hold no `GOVERNANCE.md` pin, so existing cases are unaffected; the new cases pin a line unrelated to Batch 6. |
| The same pinned lines | `reports/master/MASTER_EXECUTION_PLAN.md`, `reports/master/MASTER_GAP_REGISTER.md` and `reports/master/MASTER_REPOSITORY_HEALTH.md`, which name `Next capability` | UNAFFECTED | They read or narrate the line and never write it; the two Masters are written here only for the new rows. |
| Criterion `check:` clauses | `changes/TEMPLATE.md`; every later contract's author | WRITE | Checks are part of the criterion text, which is frozen at Approval as today (`ACCEPTANCE_TEXT_MUTATED`). |
| CTRL-17, CTRL-18 and CTRL-19 are registered | `reports/master/MASTER_GAP_REGISTER.md` | WRITE | Three rows after CTRL-16, plus the freshness header (Check 21). |
| CTRL-19 is open and waits on the owner | `reports/master/MASTER_EXECUTION_PLAN.md` Action registry (Check 29); the manifest's open-decision line (Checks 11, 14 and 25) | WRITE | Prototype consistency CLEAN: 10 decision ids resolve, 9 register entries awaiting a decider are on the boot line, and the registry classifies CTRL-19 as NOT DUE at `GATE-EVAL`. |
| The manifest's `Last Completed` names this contract, and its Active Change Request this contract and then `None.` | Boot; `ai-map.json` and `repository-index.md` (Check 7) | WRITE | `CR_LIFECYCLE.md` §9; the manifest stays under Check 5's budgets (6,695 of 7,000 characters at `e110626`). |
| `-Gate -Trusted` | `scripts/promote_main.ps1`, its one caller | WRITE | New and opt-in. No hook or workflow invokes it, so no existing path changes (281-T1…T4). |
| The `SPEC-280` LEARN clause is corrected and the assurance paragraph added | `ENGINEERING_METHOD.md` readers; Check 27's 25 anchors | VERIFY | Prototype Check 27: all 25 present. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Each Step 1 file holds its `from` or `to` blob, and the manifest holds Step 1's old or new text | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| The pinned lines hash to their pins, and repository consistency is CLEAN | BEFORE_COMPLETION | NONE | NONE | 2 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `Evaluate-PreApprovalEvidence`, `Validate-CommittedRange` and the existing transition checks (`Validate-Checklist`, `Validate-EvidenceAppendOnly`, `Validate-CompletionPrerequisites`), with the control suite's fixtures, mutation helpers and population census. They are extended, never duplicated: the endpoint and the walk now call the same two functions.

Added Property: CI re-proves every contract transition the hook judges; a line that names its owner keeps its ratified text; an authority change closes its `git grep`-derived consumers; a criterion's checks are satisfiable at Approval and hold at Complete; a candidate can be judged by an evaluator it does not control, and promoted only as the SHA that was judged.

Causal Negative: At `e110626`, the four `--no-verify` ranges were READY in range mode; `SPEC-278`'s exact Draft text was admitted on the Draft-to-Approved transition; a copied target in `Next capability` left repository consistency CLEAN; a candidate that neutered its own evaluator was READY under it.

Positive Test Design: 281-P5, C5, C8, S3, S6, A2, A4, T4, R1 and R5 are admitted, and the 12 published ranges keep their verdicts.

Negative Test Design: 281-P1…P4, C1…C4, C6, C7, S1, S2, S4, S5, S7, A1, A3, T1…T3, R2…R4 and R6 are refused, each asserted on its own code or subject.

Non-Empty Population Obligation: the families PARITY, CHECK, PIN, ACI, TRUST and PROMOTE each record at least one accept, one reject and one mutation in the suite's census.

Mutation Obligation: 281-PM, CM1…CM3, SM1…SM3, AM1, AM2, TM1…TM3, RM1 and RM2 each disable one load-bearing predicate and are killed by a scenario only it refuses; every mutation applies at exactly one place and leaves valid syntax.

Post-Implementation Proof Obligation: `-Finish` passes the five CONTROL suites with the new cases; the range Gate over this contract's publication range is READY; `-Gate -Trusted`, run from a checkout outside the candidate, is READY on this contract's final commit.

## Implementation Steps

1. **Check** each file below with `git hash-object --path=<path> <path>`. If every file equals its `to` blob and the manifest holds the new text below, record Already Applied. Otherwise, for each file that equals its `from` blob, or is absent where it says so, write with the reviewed content summarised in Notes, so that its blob becomes exactly the `to` blob. Any other blob means stop and report; do not guess.
   - `scripts/check_agent_continuity.ps1`: from `20368053631981aed041afe92e3ce74b1eb9c285` to `d9d485b9a3bfa099af092648228e8bb005320471`
   - `scripts/test_agent_continuity.ps1`: from `e9499704a646bd06d733fb0abb850f91d23af180` to `7f0843fd3ff31433e8c643b01298ab8d589dfe83`
   - `scripts/promote_main.ps1`: from absent to `bf64aa893faf9d6be7477254bebf80dca04b4d79`
   - `GOVERNANCE.md`: from `f0e245b09c5b4e7beff2e80b61216e3eb3a5c1e4` to `98f672d322aa0c1fdc6f3a65d6e2f5fe9648af97`
   - `CR_LIFECYCLE.md`: from `d65a85ffab56635f1aa2251301c8c036a30467f4` to `44e167cdefb16561cd5dfb9db78cc4b6355fb6cb`
   - `ENGINEERING_METHOD.md`: from `7ccc836b6521c60ab859b2fb845d3c37b8f2ac35` to `e844e85adb4d21b83b01bf8a0c7328e8a379bebf`
   - `changes/TEMPLATE.md`: from `b386a61a27d4a74780e3706daec925f76d21c62a` to `ce6536b8d9169d1793f7c35379c5b59da1079eba`
   - `reports/master/MASTER_GAP_REGISTER.md`: from `8c80a6a6ca17f65cd871d5386f1d6e5166e0937f` to `7f957064cf1c3622229e220a85ae123c63648f1c`
   - `reports/master/MASTER_EXECUTION_PLAN.md`: from `1fcdefb98908576d5ce98b6f0dbe89edf502b940` to `e957b949bc330cb637a634644664bf93bd2eb5ce`

   `GOVERNANCE.md` §6 gains these three pins, one per manifest line that names its owner:

   | `_ORVION_CANONICAL/manifest.md` | `Current Module` | `scripts/batch6_select_target.ps1` | `63c303fb1bcfde20de5d8f6c9f16ab38436e451c6bf8795cb93d7da97114ca77` |
   | `_ORVION_CANONICAL/manifest.md` | `Batch 6 surface coverage` | `reports/master/MASTER_SURFACE_DISPOSITION.md` | `166b2f42e10851e6c13be8d578229e72ff22865d6761bfb2a2d8f78296ce8a16` |
   | `_ORVION_CANONICAL/manifest.md` | `Next capability` | `scripts/batch6_select_target.ps1` | `c03a5e39b0beafeb08781346fb05f5968aed98e96587036a9f2ec48f423d55b5` |

   In `_ORVION_CANONICAL/manifest.md`, replace each old text below, which must occur exactly once, with its new text, and change no other line:

   Old text:

   ```text
   **OD-8**, **OD-9**. The OD rows
   ```

   New text:

   ```text
   **OD-8**, **OD-9**, **CTRL-19**. The OD rows
   ```

   Old text:

   ```text
   No email is sent and no retention policy is seeded while those prerequisites remain.
   ```

   New text:

   ```text
   No email is sent and no retention policy is seeded while those prerequisites remain. CTRL-19 is GitHub configuration only the owner can make.
   ```

   Old text:

   ```text
   Last Completed: **SPEC-279: Batch 6 Slice 42 is closed — a used ledger account keeps its meaning (`chart_of_accounts`; COA-1 and COA-2 fixed by migration `20261013120000`, deployed to Primary under the cancelled SPEC-278 and carried forward here).**
   ```

   New text:

   ```text
   Last Completed: **SPEC-281: assurance is enforced by the Gate — CI re-proves every transition the hook judges, owner-naming manifest lines are pinned, an authority change closes its derived consumers, and criterion checks are verified (CTRL-17 and CTRL-18 fixed; CTRL-19 waits on the owner).**
   ```

2. **Check** whether the Runtime Checkpoint reads `Resume Step: DONE`. If so, record Already Applied. Otherwise:
   - run `pwsh -NoProfile -File scripts/generate-ai-map.ps1` and keep what it writes to `ai-map.json` and `repository-index.md`;
   - confirm that `git diff --name-only` against the Approve commit lists only Write Scope paths, and stop and report any other path;
   - synchronize the Execution Log, set the Runtime Checkpoint to `DONE`, and commit the implementation and checkpoint together;
   - then run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` normally. If a test fails, keep its exit code and evidence, and follow bounded recovery without weakening any assertion.

## Acceptance Criteria

- [x] The evaluator is the reviewed one. `check: blob scripts/check_agent_continuity.ps1 d9d485b9a3bfa099af092648228e8bb005320471`
- [x] The control suite is the reviewed one. `check: blob scripts/test_agent_continuity.ps1 7f0843fd3ff31433e8c643b01298ab8d589dfe83`
- [x] The owner's promotion script is the reviewed one. `check: blob scripts/promote_main.ps1 bf64aa893faf9d6be7477254bebf80dca04b4d79`
- [x] `GOVERNANCE.md` carries rule 10 and the three pins. `check: blob GOVERNANCE.md 98f672d322aa0c1fdc6f3a65d6e2f5fe9648af97`
- [x] `CR_LIFECYCLE.md` states range parity, criterion checks and §9's treatment of pinned lines. `check: blob CR_LIFECYCLE.md 44e167cdefb16561cd5dfb9db78cc4b6355fb6cb`
- [x] `ENGINEERING_METHOD.md` corrects the history clause and states what the Gate enforces and what stays judgment. `check: blob ENGINEERING_METHOD.md e844e85adb4d21b83b01bf8a0c7328e8a379bebf`
- [x] The template shows a criterion how to carry a check. `check: blob changes/TEMPLATE.md ce6536b8d9169d1793f7c35379c5b59da1079eba`
- [x] The register holds CTRL-17, CTRL-18 and CTRL-19. `check: blob reports/master/MASTER_GAP_REGISTER.md 7f957064cf1c3622229e220a85ae123c63648f1c`
- [x] The Action registry classifies CTRL-19. `check: blob reports/master/MASTER_EXECUTION_PLAN.md e957b949bc330cb637a634644664bf93bd2eb5ce`
- [x] The manifest names CTRL-19 among the open decisions and this contract as last completed. `check: has _ORVION_CANONICAL/manifest.md "**OD-9**, **CTRL-19**."` `check: has _ORVION_CANONICAL/manifest.md#Last Completed "SPEC-281"`
- [x] The three pinned lines are byte-identical to `e110626`. `check: same _ORVION_CANONICAL/manifest.md#Current Module @e110626` `check: same _ORVION_CANONICAL/manifest.md#Batch 6 surface coverage @e110626` `check: same _ORVION_CANONICAL/manifest.md#Next capability @e110626`

## Execution Log

### 2026-10-14 — Claude

Outcome: Implemented. The Runtime Checkpoint is DONE; `-Finish` follows.

Step results:
- **Step 1: Applied.** Each of the nine files held its `from` blob (`scripts/promote_main.ps1` was absent) and now holds its `to` blob, written from the reviewed content and re-hashed with `git hash-object --path`. Each manifest old text occurred exactly once and was replaced by its new text. The three pinned lines hash to their `GOVERNANCE.md` §6 pins.
- **Step 2: Applied.** `scripts/generate-ai-map.ps1` rewrote `ai-map.json`; `repository-index.md` was unchanged. `git diff --name-only 53ac0d8` (the Approve commit) listed only Write Scope paths, and `git diff --check` was clean. The Runtime Checkpoint is DONE.

**Approval prerequisites, re-verified before the first commit.**
- HEAD, `origin/main`, and GitHub's `main` and `orvion-preflight` were `e110626`; the only change in the tree was the untracked Draft; no other worktree or stash existed.
- The Draft's blob was `a7ea441eb8f185bed850adde535c047a99c2fa94`, its SHA-256 `3fbe9914d5080debd9a1c3913e59a08ad13d5a6daa9156fd4315cafded5593dc`, 30851 bytes, 0 CR, recomputed from its bytes and equal to the approved identity in full.
- `SPEC-281` appeared in no tracked text before the Draft commit. The Approve commit's hook returned `APPROVAL_EVIDENCE: PASS`.

**The owner's three questions at Gate 1, answered from the code.**
- **A. A `check:` clause is data.** The four forms are matched by fixed patterns: a `same` commit and a `blob` id are hex only, `has` and `lacks` text is compared literally (`String.Contains`), and a `#key` is regex-escaped. No command, expression, script or regex is built from a clause, and every Git argument it reaches is anchored by a hex revision or follows `--`. A check can only refuse, never admit. One ceiling: the endpoint reads a check's path in the working tree without confining it, so a `..` path reads a local file outside the checkout. That read executes and writes nothing, and the range walk, which `-Trusted` always runs, reads the same check from Git objects, where such a path does not exist, so the candidate is refused. No change.
- **B. The promoter runs `main`'s evaluator, never the candidate's.** `scripts/promote_main.ps1` (line 38) runs `scripts/check_agent_continuity.ps1` from its own checkout, which it refuses unless that checkout is a clean `origin/main` (line 26), with `-Root` set to the candidate's data checkout. `-Trusted` independently refuses an evaluator inside `-Root` (281-T2), and 281-R2 shows a candidate that certifies itself judged by `main`'s evaluator and refused. Notes' "runs that checkout's evaluator" means the judge checkout's, as owner action 3 and the script's header say. Wording only; Notes is frozen, so the clarification is recorded here.
- **C. The measured cost is missing from Notes,** although Risks places it there: the "Measured cost" bullet was left without its figures. They are, for the same work on the same machine, `e110626`'s Gate against the new one: `SPEC-280`'s range 19.3 s and 19.3 s; `SPEC-279`'s two-contract range 27.1 s and 27.6 s (median of 3); the hook on an Approval 12.9 s and 13.3 s (median of 5); the control suite 446 and 501 cases, the 55 new ones about 3.6 minutes alone; the rehearsal's `-Finish` 35.1 minutes. Model tokens were not measured. In the same Notes, the "First publication" and "Considered and not adopted" bullets run on from the line before them; their text is complete.

Commits: Draft `5a02370`, Approve `53ac0d8`, Begin `cda133b`, and this Implement commit.

## Verification Notes

### 2026-10-14 — Claude (independent review)

Verdict: Confirmed Complete

Findings: re-checked against the live repository at `f925736`, not against the Execution Log.
- **R1.** At `HEAD` each of the nine Step 1 files is its `to` blob: `scripts/check_agent_continuity.ps1` `d9d485b9a3bfa099af092648228e8bb005320471`, `scripts/test_agent_continuity.ps1` `7f0843fd3ff31433e8c643b01298ab8d589dfe83`, `scripts/promote_main.ps1` `bf64aa893faf9d6be7477254bebf80dca04b4d79`, `GOVERNANCE.md` `98f672d322aa0c1fdc6f3a65d6e2f5fe9648af97`, `CR_LIFECYCLE.md` `44e167cdefb16561cd5dfb9db78cc4b6355fb6cb`, `ENGINEERING_METHOD.md` `e844e85adb4d21b83b01bf8a0c7328e8a379bebf`, `changes/TEMPLATE.md` `ce6536b8d9169d1793f7c35379c5b59da1079eba`, `reports/master/MASTER_GAP_REGISTER.md` `7f957064cf1c3622229e220a85ae123c63648f1c`, `reports/master/MASTER_EXECUTION_PLAN.md` `e957b949bc330cb637a634644664bf93bd2eb5ce`.
- **R2.** The manifest's word diff from `e110626` is the Active Change Request and Step 1's three texts, nothing else. Its `Current Module:`, `Batch 6 surface coverage:` and `Next capability:` lines are each ordinally equal to their `e110626` text and hash to their `GOVERNANCE.md` §6 pins. `**OD-9**, **CTRL-19**.` is present, and `Last Completed:` names `SPEC-281`.
- **R3.** `e110626..HEAD` changes exactly twelve paths, all in Write Scope; `repository-index.md` regenerated unchanged. No Out of Scope path differs from `e110626`.
- **R4.** Since the Draft commit `5a02370`, which holds the approved blob `a7ea441eb8f185bed850adde535c047a99c2fa94`, this contract changed only in Status, the Runtime Checkpoint and the Execution Log; its headings are identical and in order. The pre-commit Gate accepted every commit, the Approve commit with `APPROVAL_EVIDENCE: PASS`.
- **R5.** `CR_LIFECYCLE.md` §9's `Complete` now rewrites `Current Module` and `Next capability` only while they name a package, and a pinned line never; `scripts/batch6_select_target.ps1` stays the owner of the next slice (`SPEC-270`), and no slice is named in the manifest.
- **R6.** The owner's three Gate 1 questions, re-read in the code at `HEAD`: a `check:` clause reaches only four fixed operations, with hex-only commits and blobs, literal text and escaped keys, so nothing it says is executed (`check_agent_continuity.ps1`, `Get-CriterionChecks` and `Test-CriterionCheck`); `promote_main.ps1` runs its own checkout's evaluator on the candidate's data checkout (lines 26 and 38). Both stand as the Execution Log records them, with its one ceiling. The cost figures Notes omitted are recorded there from the Gate 1 measurements.
- **R7.** `-Finish` at `f925736`: the five CONTROL suites, `scripts/test_agent_continuity.ps1` with this contract's cases among them, repository consistency and `git diff --check` PASS; `LOCAL_CERTIFY: READY` in 34.97 min.
- **R8.** Not this contract's to fix, for the next programme: Notes' run-on bullets and promoter wording (recorded in the Execution Log); `MASTER_GAP_REGISTER.md`'s CTRL-19 row cites the promotion tests as 281-R1…R5, while R6, the lease refusal, also exists; the endpoint's unconfined working-tree read of a check's path (the Execution Log's ceiling). None makes an Acceptance Criterion or a Review Gate item false.
- **R9.** No Primary or Secondary contact, no migration, and no GitHub setting, ruleset, permission or credential was changed.

Review Gate: every step matched its text and was Applied. Nothing was written outside Write Scope, and no section was restructured. Every Acceptance Criterion is true, and the Gate verifies all eleven at this commit (``CRITERIA: 11 of 11 verified by the Gate; 0 judged by Review alone``). No step needed a guess. `Supersedes / Depends On` is None. The tree is clean.

Complete introduces no new architectural decision: the owner approved this contract at Gate 1 on 2026-10-14. CTRL-19 stays open until the owner's GitHub configuration is observed; the first promotion is the owner's.

## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as
      Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created, or deleted.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's
      Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

- **The reviewed content (Step 1), by file.**
  - `scripts/check_agent_continuity.ps1`:
    - `Validate-RecordedText` and `Validate-TransitionEvidence` judge a contract's transitions at the endpoint and at each commit of the walk.
    - `Validate-PinnedAuthority` holds each pinned line to its pin in every mode.
    - `Assert-AssuranceAdmission` judges, at Approval and for every contract: criterion checks that can never hold, or that contradict each other; a step naming a pinned line without a disposition; a WRITE on a pinned line that does not move its pin; and a moved pin's derived consumers.
    - The walk judges each commit that moves a pin.
    - Completion verifies every `check:`.
    - `CRITERIA` reports Gate-verified against judged criteria.
    - `-Trusted` refuses an evaluator inside `-Root` (`TRUSTED_EVALUATOR_IN_CANDIDATE`) and data that is not exactly the candidate SHA (`TRUSTED_DATA_NOT_CANDIDATE`), and does not run Repo-Guard.
    - `Test-EvidenceAuthorityPath` names `scripts/promote_main.ps1` beside `scripts/publish_candidate.ps1`.
  - `scripts/promote_main.ps1` (new): the owner's promotion.
    - It refuses unless run from a clean checkout of `origin/main`.
    - It checks the candidate out as data with hooks disabled, and runs that checkout's evaluator with `-Gate -Trusted`.
    - It pushes exactly the judged SHA, under a lease on the judged `main`.
  - `scripts/test_agent_continuity.ps1`:
    - `ContractText` gains `-Steps`.
    - Thirty-five cases, fourteen mutations and six census assertions (281-*), on a pinned line unrelated to Batch 6.
    - Two RANGE-AUTHORITY mutations are retargeted to the shared functions.
    - The census covers the families PARITY, CHECK, PIN, ACI, TRUST and PROMOTE.
  - `GOVERNANCE.md`: §6 rule 10 and its pin table, and v1.20 in the version line and the changelog.
  - `CR_LIFECYCLE.md` §8:
    - a paragraph on range parity and criterion checks;
    - `SPEC-167`'s sentence now lists only the manifest pointer and the receipt as judged at `HEAD`.
  - `CR_LIFECYCLE.md` §9: `Complete` rewrites `Current Module` and `Next capability` only when they name a package.
  - `ENGINEERING_METHOD.md` §2:
    - the history clause reads each written line's own history (`git log -L`) and calls history evidence, never authority;
    - the paragraph "Assurance is enforced by the Gate, not by the reader".
  - `changes/TEMPLATE.md`: the Acceptance Criteria instructions show the four check forms.
  - `reports/master/MASTER_GAP_REGISTER.md`: the CTRL-17, CTRL-18 and CTRL-19 rows and the freshness header.
  - `reports/master/MASTER_EXECUTION_PLAN.md`: CTRL-19's registry row and the freshness header.
- **Owner actions this contract cannot take (CTRL-19).** Each is GitHub configuration or credential separation outside the repository, so it is a recommendation until it is observed. Nothing here changes a ruleset, a permission or a credential.
  1. **A separate agent identity, with nothing of the owner's within its reach.**
     - Today the agent runs as the owner's Windows user. There the owner's administrator login is reachable through the `gh` keyring, Git Credential Manager, Windows Credential Manager and a `GITHUB_PAT_TOKEN` environment variable. These are names read on 2026-10-14; no value was read.
     - Run the agent under its own operating-system account, VM or container. Its only GitHub credential should belong to a separate GitHub account, added to `PlatPlusHub/CRM` with the Write role. `Shehabhub` is a candidate.
     - The repository's scripts need only Contents and Workflows write, and Actions read.
     - Inside one operating-system account, no setting hides the owner's credentials from the agent. A token of the owner's own account carries the owner's role.
  2. **Two rulesets on the default branch.**
     - Keep Ruleset 22950574 exactly as it is: `orvion-acceptance` required, non-fast-forward and deletion blocked, no bypass actor.
     - Add a second ruleset with one rule, `update` (Restrict updates, `update_allows_fetch_and_merge: false`). Its only bypass actor is the owner's account: `actor_type: User`, id `318555370`, bypass mode `always`. GitHub added individual users as bypass actors on 2026-05-07 (changelog), and its REST reference lists `User` and `update`.
     - A bypass is listed per ruleset, so the owner's push should still have to satisfy the first ruleset's required check. GitHub's documentation does not say so outright, so step 4 tests it.
  3. **Promote with `scripts/promote_main.ps1`.** From the owner's own context, in a clean checkout of `main`, run `pwsh -NoProfile -File scripts/promote_main.ps1 -Candidate <40-hex SHA>`.
     - It refuses unless its checkout is exactly `origin/main` and the candidate descends from it.
     - It checks the candidate out as data with hooks disabled, and requires READY from `main`'s own evaluator under `-Gate -Trusted`.
     - It then pushes that SHA under a lease on the `main` it judged. GitHub still applies the required check.
  4. **Verification, before relying on it.**
     - Read-only, from the agent's context:
       - `gh api user` names the agent's account;
       - `gh api repos/PlatPlusHub/CRM --jq .permissions` shows `admin: false` and `maintain: false`;
       - `cmdkey /list` and `git credential-manager github list` show no owner entry, and the environment holds no owner token;
       - `gh api repos/PlatPlusHub/CRM/rules/branches/main` lists `update` beside `required_status_checks`.
     - Behavioural, on a disposable branch so that `main` is never at risk:
       - the owner adds `refs/heads/ruleset-probe` to both rulesets' targets;
       - the agent's push to it is refused;
       - the owner's push of a commit without `orvion-acceptance` is refused;
       - the owner's push of a commit that passed `orvion-acceptance` is accepted;
       - the probe target is then removed.

  **Residual risks after all four.**
  - The owner's account can still update `main` without the script. The script binds every promotion the owner runs through it, not every push the owner could make.
  - `orvion-acceptance` is still computed by the candidate and still counts `skipped` as passing. It adds evidence, never trust.
  - Gate 1 approval is still a commit an agent writes. Only signed owner approvals would make it cryptographically the owner's.
  - An administrator can edit both rulesets, by design.

  Until all four are observed, CTRL-19 stays open, and no trusted publication path is claimed.- **First publication: the trust bootstrap.** `main` at `e110626` holds neither `-Trusted` nor `scripts/promote_main.ps1`, so neither can judge its own first promotion. The agent publishes the candidate to `orvion-preflight` with `scripts/publish_candidate.ps1`, reports `orvion-acceptance` on that exact SHA, and stops. The owner alone promotes it, once, from the owner's own context, in a fresh clone of `PlatPlusHub/CRM` at `main`:
  1. Fetch `orvion-preflight`, and confirm the candidate descends from `main`.
  2. Confirm that the candidate's `scripts/check_agent_continuity.ps1` and `scripts/promote_main.ps1` have exactly the `to` blobs Step 1 pins. They are then bytes the owner approved at Gate 1, not merely bytes the candidate carries.
  3. Confirm that, under `scripts/` and `.githooks/`, the candidate changes only `scripts/check_agent_continuity.ps1`, `scripts/test_agent_continuity.ps1` and `scripts/promote_main.ps1`. Every file `main`'s evaluator runs from the candidate is then byte-identical to `main`'s: `scripts/check_repository_consistency.ps1`, and the `generate-ai-map.ps1`, `check_primary_ledger.ps1` and `readiness_population.ps1` it calls.
  4. Check the candidate out as data with hooks disabled.
  5. Run two judges:
     - `main`'s own evaluator, `-Gate -Root <data> -BaseRef <main> -HeadRef <candidate>`: `e110626`'s rules, by `main`'s code;
     - the approved evaluator, copied out of the data checkout, `-Gate -Trusted -Root <data> -BaseRef <main> -HeadRef <candidate>`: the new rules, by owner-approved bytes.
  6. Only on two READYs, push exactly that SHA under a lease: `git push origin <candidate>:refs/heads/main --force-with-lease=refs/heads/main:<main>`.

  During the bootstrap, the guarantees are `e110626`'s predicates run by `main`'s code, plus the new predicates run by bytes the owner approved and that were executed outside the candidate. After it, every promotion runs `scripts/promote_main.ps1` from a clean checkout of `main`. Its evaluator and promoter are then the installed ones, which the owner promoted (281-R1…R6).- **Considered and not adopted, with the evidence.**
  - *Checking that every path a contract cites exists.* Over the 86 contracts since `SPEC-196` it flagged 60 citations, none of them a stale path: figures, `N/A`, URLs and abbreviations.
  - *Requiring a dependency to be terminal.* Over 49 citations since `SPEC-150` it raised two refusals and no true positive. `SPEC-170` cancelled an Approved predecessor within its own execution, and `SPEC-191` named a Draft that depends on it.
  - *Write-closure rules for `scripts/verify_database.sql` and `repository-consistency.yml`.* Each would have caught one cancellation (`SPEC-194`, `SPEC-186`), but it would widen write authority over a guard file in 34 and 7 contracts that did not need it.
  - *A trusted check run from `main` by `workflow_run`.* Running from `main` does not establish trust on its own. Any workflow can post a check under the GitHub Actions identity, so a candidate can impersonate it, and `main` itself moves on a check the candidate defines. It needs an owner-held GitHub App, an environment restricted to `main`, and the update restriction above. That is a new external identity, which needs its own owner authorization. `scripts/promote_main.ps1` is the smaller owner-run binding, and needs no new identity.
  - *Signed owner approvals.* They would make Gate 1 cryptographically the owner's. They are a change to how the owner works, and are left to the owner.
  - *Copied-text detection, a dependency database, and a model-based reviewer.* `AGENTS.md` §7 excludes generic semantic engines without separate owner approval, and deterministic predicates covered the measured failures.
  - *Mandatory rehearsal.* `SPEC-274` ratified rehearsal as risk-based. The Gate now proves the formalizable part.
- **What stays judgment.**
  - Whether a declared disposition is true.
  - Whether a criterion with no check is met.
  - Any contradiction written as neither a check nor a pin.
  - Whether a `git grep` candidate is a material consumer, rather than a file to disposition.

  `CRITERIA` makes the second visible at Gate 1.
- **Measured cost, same work on the same machine, current Gate against new.**
- **Rehearsal.** The reviewed content was prototyped in push-disabled clones of `e110626`. This contract's whole lifecycle, on these exact bytes, was committed in a fresh one, with the repository's pre-commit hook judging every commit. That lifecycle was judged by `-Finish`, the range Gate and `-Gate -Trusted`. The Gate 1 report records the results. The last 12 ranges `main` published were replayed with the new evaluator (Risks).
- **Not this contract's work:** Batch 6 Slice 43, which `scripts/batch6_select_target.ps1` chooses when it begins.
