# Change Request — SPEC-280

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Record SPEC-278's open follow-ups where they are enforced or owned: the blank chart-account code's reopening trigger as a live deferred item at `ENABLE-CLIENT-WRITES`, and the two of its four lessons that no authority yet owns.

## Business Reason

- **The blank-code trigger is recorded but not linked.** SPEC-278 measured that once a tenant creates an account coded `''`, `app.create_journal_entry` posts a line with an empty `account_code` to it. It judged the consequence bounded and recorded the observation as a position in the `chart_of_accounts` row of `MASTER_SURFACE_DISPOSITION.md`, with the reopening trigger `ENABLE-CLIENT-WRITES`. `scripts/readiness_population.ps1` (Check 29) takes no member from an `AUDITED` row's text. Measured in a disposable clone of `f4233f3` with that boundary set `REACHED`: Check 29 reported four other items OVERDUE and never the blank code. With the row this contract adds, it also reported the blank code OVERDUE. The backlog's Live deferred items table is the governed home for a trigger-bound item (`ENGINEERING_METHOD.md` §3 "Nothing open is lost"), and it already holds two rows at this boundary.
- **The four lessons, each checked against the current authorities:**
  - *Run every generator before predicting a derived file unchanged.* Already owned. `ENGINEERING_METHOD.md` §2 says a prototype exists so that a Draft's Pre-Approval Evidence is "written from observation rather than prediction". The SPEC-210 write closure refuses at Approval a migration contract that does not carry `MASTER_API_CONTRACT.md`. SPEC-278 carried it, so the misprediction cost nothing. No change.
  - *Read a full log, not a filtered one.* Already owned. `ENGINEERING_METHOD.md` §3 has "A harness result is evidence only after every participant's own output is read" (added by SPEC-278 itself) and "Quote only what a log printed". The truncated self-test output was re-read in full before anything was concluded. No change.
  - *Check later rules before copying a precedent.* Not owned. SPEC-278 copied SPEC-268's manifest step after SPEC-270 had deleted exactly that copy (CTRL-12), and the frozen criterion could never be made true. This cost a cancellation, a successor contract and two owner decisions. One `git log <precedent>..HEAD -- <file>` would have shown it. Batch 6 has 35 more slices, each likely to copy the last. **One clause is added to LEARN BEFORE GUESSING's "relevant history" item.**
  - *After a stash or checkout, verify a pinned file's SHA-256, not only its blob.* Not owned. `CODING_STANDARDS.md` §12 covers a CRLF file an agent writes, but not one Git writes. On this workstation `core.autocrlf=true` and there is no `.gitattributes`. A `git stash pop` rewrote SPEC-278's Gate-2 migration as CRLF while its blob still matched; the SHA-256 pin caught it before Primary. Clones and checkouts did the same on 2026-09-07 (`reports/history/session-2026-09-07-local-first-state-reaudit.md`). `CODING_STANDARDS.md` is itself checked out with CRLF here today. **One sentence is added to the existing "Write repository text with LF" item.**

## Risks

- **A wrong row at a live boundary.** The row fails Check 29 only when `ENABLE-CLIENT-WRITES` is recorded `REACHED` while it is still there, which is its purpose. Today the boundary is `NOT REACHED`, so the row reads NOT DUE, and nothing else moves.
- **Rule accretion.** Two clauses are added inside existing items. No section, heading, gate, register or script is added, and the two lessons already owned are not repeated.
- No other material risk: no migration, schema, Primary or Secondary action, and no Batch 6 slice.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-280-the-ledger-slices-follow-ups-reach-their-owners.md`
- `reports/future-backlog.md`
- `ENGINEERING_METHOD.md`
- `CODING_STANDARDS.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-278-a-used-ledger-account-keeps-its-meaning.md`
- `changes/SPEC-279-the-ledger-account-slice-is-closed-and-published.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `scripts/readiness_population.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/check_repository_consistency.ps1`
- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `changes/TEMPLATE.md`
- `.gitattributes`
- `supabase/migrations/20261013120000_a_used_ledger_account_keeps_its_meaning.sql`

## Required Reading

- `changes/SPEC-278-a-used-ledger-account-keeps-its-meaning.md` (Business Reason, Execution Log, Notes)
- `reports/future-backlog.md` ("Live deferred items")
- `reports/master/MASTER_EXECUTION_PLAN.md` (the Action registry's Boundaries table)
- `ENGINEERING_METHOD.md` §§2–3
- `CODING_STANDARDS.md` §12

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github

## Additional Verification

None

## Pre-Approval Evidence

Change Class: Routine

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| The blank code is a live deferred item at `ENABLE-CLIENT-WRITES` | `scripts/readiness_population.ps1` (Check 29, `-Registry`) | WRITE | Prototype in a disposable clone of `f4233f3`: `-Registry` lists it `NOT DUE`, `LIVE DEFERRED ITEM`, `ENABLE-CLIENT-WRITES (NOT REACHED)`, with 11 live items. With that boundary set `REACHED`, it is reported OVERDUE and the run exits 1. With the `f4233f3` backlog, the same run reports four other items and never the blank code. Repository consistency CLEAN. |
| The `chart_of_accounts` position and its trigger | `MASTER_SURFACE_DISPOSITION.md`; Checks 22 and 24 | UNAFFECTED | The row keeps its text and `AUDITED` state; the backlog row points to it. |
| A boundary or registry row | `MASTER_EXECUTION_PLAN.md` | UNAFFECTED | `ENABLE-CLIENT-WRITES` already exists, and a backlog row needs no registry row (`SPEC-270`). |
| LEARN BEFORE GUESSING's "relevant history" item gains one clause | `ENGINEERING_METHOD.md` readers; Check 27 (relocated rules); the pointer scan | VERIFY | One line changes, and no heading or anchor moves. Prototype consistency CLEAN. |
| `CODING_STANDARDS.md` §12's LF item gains one sentence | `CODING_STANDARDS.md` readers; the pointer scan | VERIFY | One line changes, and no heading moves. Prototype consistency CLEAN. |
| The manifest's Active Change Request names this contract, then `None.` | The Gate; `ai-map.json` and `repository-index.md` (Check 7) | WRITE | Set by the Approve and Complete commits and regenerated by `scripts/generate-ai-map.ps1`. `Last Completed`, `Current Module` and `Next capability` do not change. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Each target file still holds its anchor text exactly once | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| Repository consistency CLEAN and only Write Scope paths changed | BEFORE_COMPLETION | 1 | 3 | 4 |

## Implementation Steps

1. **Check** whether `reports/future-backlog.md` contains the row below. If so, record Already Applied. Otherwise, if exactly one line begins `| Frontend design tooling and dashboard contracts`, insert the row as a new line directly after it, and change nothing else. Otherwise stop and report.

   ```text
   | A blank chart-account code is a postable selector: once a tenant creates an account coded `''`, `app.create_journal_entry` posts a line with an empty `account_code` to it instead of refusing the line | engineering | The first client application that submits journal lines. Measured on 2026-10-13 and not repaired, because its consequence is bounded today: only the tenant's own step-up poster can create that account, and the money lands on a real, typed account (`SPEC-278`) | `ENABLE-CLIENT-WRITES` | The `chart_of_accounts` row of `reports/master/MASTER_SURFACE_DISPOSITION.md` |
   ```

2. **Check** whether `ENGINEERING_METHOD.md` contains the new text below. If so, record Already Applied. Otherwise, if it contains `the relevant history in Git, the register and the CRs;` exactly once, replace that text with the new text, and change nothing else. Otherwise stop and report.

   ```text
   the relevant history in Git, the register and the CRs, including every later change to a line that a Step or Criterion copied from a precedent will write (`git log <precedent>..HEAD -- <file>`): `SPEC-278` copied `SPEC-268`'s manifest step after `SPEC-270` had deleted that copy, and was cancelled;
   ```

3. **Check** whether `CODING_STANDARDS.md` contains the new text below. If so, record Already Applied. Otherwise, if it contains `as the generators do.` exactly once, replace that text with the new text, and change nothing else. Otherwise stop and report.

   ```text
   as the generators do. Git can also write them: with `core.autocrlf=true` and no `.gitattributes`, a Windows checkout, clone or `git stash pop` materializes LF files as CRLF while `git hash-object` still reports the LF blob, so a file whose exact bytes matter, such as a migration bound for Primary, is verified by its SHA-256, not by its blob (`SPEC-278`).
   ```

4. **Check** whether the Runtime Checkpoint reads `Resume Step: DONE`. If so, record Already Applied. Otherwise:
   - confirm that `git diff --name-only` against the Approve commit lists only `reports/future-backlog.md`, `ENGINEERING_METHOD.md`, `CODING_STANDARDS.md` and this contract, and stop and report any other path;
   - synchronize the Execution Log, set the Runtime Checkpoint to `DONE`, and commit;
   - then run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` normally.

## Acceptance Criteria

- [x] `reports/future-backlog.md` has blob `82fbffa049559b7724e1ed62bd4fca038bbae60a`: its `f4233f3` text plus only the Step 1 row, directly after the frontend row.
- [x] `pwsh -NoProfile -File scripts/readiness_population.ps1 -Registry` lists the blank chart-account code as a `LIVE DEFERRED ITEM` at `ENABLE-CLIENT-WRITES (NOT REACHED)`.
- [x] `ENGINEERING_METHOD.md` has blob `7ccc836b6521c60ab859b2fb845d3c37b8f2ac35`: its `f4233f3` text with only the Step 2 replacement.
- [x] `CODING_STANDARDS.md` has blob `3b4a55aad4eff41eb7f79e981b49b8b100fc0bdf`: its `f4233f3` text with only the Step 3 replacement.
- [x] The manifest's `Last Completed:`, `Current Module:` and `Next capability:` lines are byte-identical to their `f4233f3` text.
- [x] Every Out of Scope file is unchanged since `f4233f3`, and the tracked implementation diff touches only this contract's Write Scope.

## Execution Log

### 2026-10-14 — Claude

Outcome: Implemented. The Runtime Checkpoint is DONE; `-Finish` follows.

Step results:
- **Step 1: Applied.** Exactly one line began `| Frontend design tooling and dashboard contracts`; the Step 1 row, taken from this contract's committed text, was inserted directly after it. `reports/future-backlog.md` is blob `82fbffa049559b7724e1ed62bd4fca038bbae60a`, one line added.
- **Step 2: Applied.** `the relevant history in Git, the register and the CRs;` occurred once in `ENGINEERING_METHOD.md` and was replaced by the Step 2 text. Blob `7ccc836b6521c60ab859b2fb845d3c37b8f2ac35`, one line changed.
- **Step 3: Applied.** `as the generators do.` occurred once in `CODING_STANDARDS.md` and was replaced by the Step 3 text. Blob `3b4a55aad4eff41eb7f79e981b49b8b100fc0bdf`, one line changed. The file had been checked out with CRLF (68 CR bytes) and is written LF.
- **Step 4: Applied.** `git diff --name-only 9e67adc` (the Approve commit) listed only `CODING_STANDARDS.md`, `ENGINEERING_METHOD.md`, `reports/future-backlog.md` and this contract. The Runtime Checkpoint is DONE.

**Approval prerequisites, re-verified before the first commit.**
- HEAD, `origin/main` and `origin/orvion-preflight` were `f4233f3` after a fetch; the only change in the tree was the untracked Draft; no other worktree or stash existed.
- The Draft's blob was `d43084958405cbbdac25dc105a26bcd94f6921fc`, its SHA-256 `9d3ee356a5f46c5e2d1e7c3207445751b3ad33d0d9be085a5b763e525e5c378b`, 12770 bytes, 0 CR, recomputed from its bytes and equal to the approved identity in full.
- `SPEC-280` appeared in no reachable history, tracked text or added path before the Draft commit.
- Each Step anchor occurred exactly once. No Primary or Secondary contact was made.

Commits: Draft `d9b4328`, Approve `9e67adc`, Begin `cf8964d`, and this Implement commit.
## Verification Notes

### 2026-10-14 — Claude (independent review)

Verdict: Confirmed Complete

Findings: re-checked against the live repository at `287a785`, not against the Execution Log.
- **R1.** At `HEAD`, `reports/future-backlog.md` is `82fbffa049559b7724e1ed62bd4fca038bbae60a`, `ENGINEERING_METHOD.md` is `7ccc836b6521c60ab859b2fb845d3c37b8f2ac35`, and `CODING_STANDARDS.md` is `3b4a55aad4eff41eb7f79e981b49b8b100fc0bdf`.
- **R2.** The word diff from `f4233f3` has exactly one hunk per file: the backlog row inserted after the frontend row; `CRs;` extended by the Step 2 clause; the Step 3 sentence appended after `as the generators do.`. Nothing else in the three files differs.
- **R3.** `pwsh -NoProfile -File scripts/readiness_population.ps1 -Registry` exits 0 and lists the blank chart-account code as `NOT DUE`, `LIVE DEFERRED ITEM`, `ENABLE-CLIENT-WRITES (NOT REACHED)`.
- **R4.** The manifest's `Last Completed:`, `Current Module:` and `Next capability:` lines are each ordinally equal to their `f4233f3` text; its only difference is the Active Change Request line, which this commit returns to `None.`. `notification_deliveries` appears in neither the manifest nor `ai-map.json`.
- **R5.** Nothing changed since `f4233f3` in SPEC-270, SPEC-278, SPEC-279, `reports/master/`, `scripts/`, `supabase/`, `.github/`, `.githooks/`, `AGENTS.md`, `CR_LIFECYCLE.md`, `GOVERNANCE.md` or `changes/TEMPLATE.md`, and no `.gitattributes` exists. The range touches only Write Scope paths.
- **R6.** Since the Draft commit `d9b4328`, this contract changed only in Status, the Runtime Checkpoint and the Execution Log. The pre-commit Gate accepted each commit.
- **R7.** `-Finish` at `287a785`: repository consistency and `git diff --check` PASS, `LOCAL_CERTIFY: READY` in 0.42 min.
- **R8.** No Primary or Secondary contact, no migration, and no script, validator, register or CI job was added.

Review Gate: every step matched its text and was Applied. Nothing was written outside Write Scope, and no section was restructured. Every Acceptance Criterion is true. No step needed a guess. `Supersedes / Depends On` is None. The tree is clean.

Complete introduces no new architectural decision: the owner approved the three changes at Gate 1 on 2026-10-14.
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

- **Considered and not adopted.**
  - A `.gitattributes` forcing LF would remove the CRLF trap at its root, but `SPEC-177` deliberately kept a repository-wide line-ending policy out of scope, and it would renormalize the whole tree. That is its own decision, not a knowledge fix.
  - A guard refusing a Batch 6 target in the manifest would contradict `SPEC-270`, which repaired CTRL-12 "by deletion, not by a new guard".
  - Backlog rows for the `account_type` and hierarchy positions: their trigger, the first consumer of the type or the hierarchy, is no registry boundary, and the `account_type` question is already closed NOT A GAP under ADR-0006. Adding a boundary for them would be new machinery that no measured consequence earns.
- **Rehearsal.** The edits were prototyped and this contract's lifecycle was committed in a push-disabled clone of `f4233f3`, judged by the Gate over the future publication range and by repository consistency.
- **Not this contract's work:** Batch 6 Slice 43, which `scripts/batch6_select_target.ps1` chooses when it begins.
