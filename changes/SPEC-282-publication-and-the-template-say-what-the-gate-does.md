# Change Request — SPEC-282

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Make the publication procedure and the Change Request template describe what the Gate enforces: publication is candidate-first under a new ADR-0031 that supersedes ADR-0009's publication sentence, stated once in `CR_LIFECYCLE.md` §9, and a contract copied from `changes/TEMPLATE.md` parses.

## Business Reason

- **The written publication procedure is not the one the repository enforces.** ADR-0009 says "Completing a CR pushes to the configured upstream." `CR_LIFECYCLE.md` §9 (`Complete`) says to publish with `git push`, line 127 says `-Certify` runs "after pushing", and `AGENTS.md` lines 36 and 150 say "push" and "normally pushed". Since `SPEC-184`, a completed contract is published by `scripts/publish_candidate.ps1` to `orvion-preflight`; ruleset 22950574 requires `orvion-acceptance` on `main`; and since `SPEC-281`, the owner promotes the exact accepted SHA with `scripts/promote_main.ps1`. The only place the real route is written is a "Standing facts" sentence inside the manifest's pinned `Next capability` line, which is a second copy of a procedure that a navigation line does not own. An agent following the lifecycle text reaches a push the ruleset is configured to refuse.
- **No decision records the change.** The ADR log's convention is that "a superseded ADR is marked Superseded and points to its replacement; it is never deleted". ADR-0031 records the route `SPEC-168`, `SPEC-184` and `SPEC-281` built. ADR-0009's Decision text is unchanged; only its Status gains the existing `Accepted (…)` qualifier form, naming the one sentence ADR-0031 supersedes. Its linear history and the additive-migration rule stay in force.
- **The template does not produce a contract that parses.** `changes/TEMPLATE.md` puts a line `---` between sections. The parser reads each section up to the next `## ` heading, so `---` becomes the last line of `Write Scope` and is refused as `INVALID_WRITE_SCOPE:---`. Measured on 2026-10-15 by calling the evaluator's own `Contract-FromText` on probe contracts, with the evaluator's functions loaded and none of its top-level code run:
  - a contract filled from the template without separators parses;
  - the same contract with the 17 separators restored, differing only in `---` and blank lines, is refused `INVALID_WRITE_SCOPE:---`;
  - six invalid contracts in the corrected structure are still refused, each with its own code: placeholder `-` left in Write Scope, the bracketed instruction left in Write Scope, a `Prove that…` Additional Verification line, `Risks` missing, two statuses ticked, and Write Scope `None` (`INVALID_WRITE_SCOPE:-`, `INVALID_WRITE_SCOPE:[List every file…`, `INVALID_ADDITIONAL_VERIFICATION`, `CONTRACT_SECTION_Risks:count=0`, `INVALID_CR_STATUS`, `EMPTY_WRITE_SCOPE`).

  No historical contract is affected: a terminal contract is never re-parsed (`CR_LIFECYCLE.md` §4).

## Risks

- **An authority change to a pinned line.** `Next capability` is pinned by `GOVERNANCE.md` §6. This contract removes one sentence from it and moves its pin in the same step, and closes the nine consumers the Gate derives. Its other text, and the `Current Module` and `Batch 6 surface coverage` lines, do not change.
- **A wrong statement of the publication route.** The new §9 text names only scripts and branches that exist at `349825e` and that `SPEC-184` and `SPEC-281` test. No script, workflow, hook, ruleset or setting changes.
- **Overstating the GitHub boundary.** ADR-0031 records that a direct push to `main` is refused as INFERENCE from configuration, not as observed behaviour, and leaves CTRL-19 open. No push to `main` is attempted to test it.
- **Template drift.** Removing the separators changes no section, heading, field or instruction. The template's other reader, the consistency guard's status-vocabulary check, reads exactly the same five states afterwards (measured).
- No other material risk: no migration, schema, Primary or Secondary action, no Batch 6 slice, and no change to `scripts/`, `.github/` or `.githooks/`.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-282-publication-and-the-template-say-what-the-gate-does.md`
- `CR_LIFECYCLE.md`
- `AGENTS.md`
- `GOVERNANCE.md`
- `_ORVION_CANONICAL/manifest.md`
- `reports/architecture-decision-records.md`
- `reports/master/MASTER_ARCHITECTURE_DECISIONS.md`
- `changes/TEMPLATE.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/publish_candidate.ps1`
- `scripts/promote_main.ps1`
- `scripts/batch6_select_target.ps1`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/agent-control.yml`
- `ENGINEERING_METHOD.md`
- `CODING_STANDARDS.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_REPOSITORY_HEALTH.md`
- `changes/SPEC-281-assurance-is-enforced-by-the-gate.md`

## Required Reading

- `CR_LIFECYCLE.md` §9 (`Complete`, `-Certify`)
- `reports/architecture-decision-records.md` (the Convention line and ADR-0009)
- `GOVERNANCE.md` §6 rule 10
- `scripts/publish_candidate.ps1` and `scripts/promote_main.ps1` (header comments)
- `changes/TEMPLATE.md`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github

## Additional Verification

None

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| The publication procedure is candidate-first and stated once | `CR_LIFECYCLE.md` §9 `Complete` and the `-Certify` paragraph | WRITE | Steps 1–2. The procedure names `scripts/publish_candidate.ps1`, `orvion-preflight`, `scripts/promote_main.ps1` and `-Certify` after `main` holds `HEAD`. |
| The same procedure, as `AGENTS.md` refers to it | `AGENTS.md` lines 36 and 150 | WRITE | Steps 3–4 point to `CR_LIFECYCLE.md` §9 instead of saying "push". |
| `Next capability` loses its "Standing facts" sentence, and its pin moves | `_ORVION_CANONICAL/manifest.md`; `GOVERNANCE.md` §6 rule 10 | WRITE | Step 5, in one step, so the pin always matches the line: `c03a5e39b0beafeb08781346fb05f5968aed98e96587036a9f2ec48f423d55b5` becomes `90b037bb396498533eb9209c81d73278a5da8ad481562a02941440a3219557ee`, recomputed from the prototype's line with the evaluator's own `Get-TextSha256`. |
| The `Next capability` line as data | `scripts/check_agent_continuity.ps1` (`Manifest`, Boot's `NEXT_CAPABILITY`); `scripts/generate-ai-map.ps1` (`next_capability`); `scripts/check_repository_consistency.ps1` (ai-map freshness) | VERIFY | All three read the line's value and none parse the removed sentence. `ai-map.json` is regenerated (Step 11). The prototype is consistency CLEAN. |
| The `Next capability` line as a fixture or reference | `scripts/test_agent_continuity.ps1` (its own fixture text); `reports/master/MASTER_EXECUTION_PLAN.md`, `reports/master/MASTER_GAP_REGISTER.md`, `reports/master/MASTER_REPOSITORY_HEALTH.md` (name the field, not its sentence) | UNAFFECTED | None of them contains "Standing facts" or depends on the removed text. |
| ADR-0009's publication sentence is superseded by ADR-0031 | `reports/architecture-decision-records.md` (Convention line); `scripts/generate-ai-map.ps1` and `scripts/impact.ps1` (locate the file only) | WRITE | Steps 6–7. No script parses an ADR's Status. The qualifier uses the log's existing `Accepted (…)` form and the Convention's word `Superseded`; ADR-0009's Decision, Why and Consequences are unchanged. |
| ADR-0009's live status in the overlay | `reports/master/MASTER_ARCHITECTURE_DECISIONS.md` (row 0009 and its freshness line, `GOVERNANCE.md` §6 rule 9) | WRITE | Steps 8–9. The previous `Last updated:` line is kept as `Previously:`, as the overlay already does. |
| The template has no separators | `scripts/check_agent_continuity.ps1` (`Contract-FromText`); `scripts/check_repository_consistency.ps1` (status vocabulary read from the template, pointer scan) | VERIFY | Step 10. Parser probes listed in Business Reason. The status-vocabulary regex reads `Draft, Approved, In Progress, Complete, Cancelled` from the prototype template, the same as at `349825e`. Historical contracts are never re-parsed (`CR_LIFECYCLE.md` §4). |
| The manifest's Active Change Request names this contract, then `None.` | The Gate; `ai-map.json` and `repository-index.md` (Check 7) | WRITE | Set by the Approve and Complete commits and regenerated by `scripts/generate-ai-map.ps1`. In the prototype, `repository-index.md` regenerates byte-identical. |
| How a candidate is published and promoted | `scripts/publish_candidate.ps1`, `scripts/promote_main.ps1`, `.github/workflows/orvion-acceptance.yml`, ruleset 22950574 | UNAFFECTED | Unchanged; this contract only describes them. CTRL-19 stays open. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Each target file still holds its anchor text exactly once | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| Every `GOVERNANCE.md` §6 pin reproduces its line | BEFORE_COMPLETION | NONE | NONE | 12 |
| `ai-map.json` matches the manifest (Check 7) | BEFORE_COMPLETION | 5 | 11 | 12 |
| Repository consistency CLEAN and only Write Scope paths changed | BEFORE_COMPLETION | 5 | 11 | 12 |

## Implementation Steps

1. **Check** whether `CR_LIFECYCLE.md` contains `publishes the range as a candidate with`. If so, record Already Applied. Otherwise, if it contains the old text below exactly once, replace it with the new text, and change nothing else. Otherwise stop and report.

   Old:

   ```text
   commits; then publishes with `git push`, confirming no local commit remains ahead of the upstream (`git rev-list @{u}..HEAD` is empty). If the push cannot complete, the Complete transition remains valid locally — git history is the source of truth — and the commits publish on the next successful push.
   ```

   New:

   ```text
   commits; then publishes the range as a candidate with `pwsh -NoProfile -File scripts/publish_candidate.ps1`, which proves the committed range with `-Gate` and pushes it to `orvion-preflight`, never to `main` (ADR-0031). `main` moves only when the owner promotes that exact candidate SHA with `scripts/promote_main.ps1`, so a candidate awaiting promotion is a valid intermediate state and `HEAD` is then legitimately ahead of `@{u}`. Once `main` holds `HEAD`, a fetch shows no local commit ahead of the upstream (`git rev-list @{u}..HEAD` is empty), and `-Certify` runs. If publication cannot complete, the Complete transition remains valid locally — git history is the source of truth — and the candidate is published on the next successful run.
   ```

2. **Check** whether `CR_LIFECYCLE.md` contains the new text below. If so, record Already Applied. Otherwise, if it contains the old text below exactly once, replace it with the new text, and change nothing else. Otherwise stop and report.

   Old:

   ```text
   run from the repository root after pushing, it reads
   ```

   New:

   ```text
   run from the repository root once `main` holds `HEAD`, it reads
   ```

3. **Check** whether `AGENTS.md` contains `synchronize, commit, publish as a candidate, clean tree`. If so, record Already Applied. Otherwise, if it contains `synchronize, commit, push, clean tree` exactly once, replace it with `synchronize, commit, publish as a candidate, clean tree`, and change nothing else. Otherwise stop and report.

4. **Check** whether `AGENTS.md` contains `committed and published as a candidate for the owner's promotion`. If so, record Already Applied. Otherwise, if it contains `committed and normally pushed; relevant CI verified.` exactly once, replace it with the new text below, and change nothing else. Otherwise stop and report.

   ```text
   committed and published as a candidate for the owner's promotion (`CR_LIFECYCLE.md` §9, `Complete`); relevant CI verified.
   ```

5. **Check** whether the `Next capability:` line of `_ORVION_CANONICAL/manifest.md` contains `Standing facts:`. If not, and the `GOVERNANCE.md` §6 pin row for it is the new row below, record Already Applied. Otherwise, if the manifest contains the sentence below exactly once, together with the space before it, and `GOVERNANCE.md` contains the old pin row below exactly once, then in one edit delete that space and sentence from the manifest and replace the old pin row with the new pin row, and change nothing else. Otherwise stop and report.

   Sentence:

   ```text
   Standing facts: Ruleset 22950574 requires `orvion-acceptance` on the default branch with `non_fast_forward`, `deletion` and zero bypass; candidates are published by `scripts/publish_candidate.ps1`, which proves the committed range first and replaces a rejected preflight candidate only under a caller-pinned lease; `main` is promoted by pushing the exact accepted SHA. Migration CI was compared on one candidate by SPEC-203: it agreed exactly.
   ```

   Old pin row:

   ```text
       | `_ORVION_CANONICAL/manifest.md` | `Next capability` | `scripts/batch6_select_target.ps1` | `c03a5e39b0beafeb08781346fb05f5968aed98e96587036a9f2ec48f423d55b5` |
   ```

   New pin row:

   ```text
       | `_ORVION_CANONICAL/manifest.md` | `Next capability` | `scripts/batch6_select_target.ps1` | `90b037bb396498533eb9209c81d73278a5da8ad481562a02941440a3219557ee` |
   ```

6. **Check** whether `reports/architecture-decision-records.md` contains `is Superseded by ADR-0031; linear history stays in force`. If so, record Already Applied. Otherwise, if it contains `- Date: 2026-07 · Status: Accepted · Source: Governance decision; SPEC-026` exactly once, replace that line with the line below, and change nothing else. Otherwise stop and report.

   ```text
   - Date: 2026-07 · Status: Accepted (its last Decision sentence, "Completing a CR pushes to the configured upstream.", is Superseded by ADR-0031; linear history stays in force) · Source: Governance decision; SPEC-026
   ```

7. **Check** whether `reports/architecture-decision-records.md` contains a line beginning `## ADR-0031 `. If so, record Already Applied. Otherwise, if exactly one line reads `## Programme lesson numbering (resolved 2026-08-31)`, insert the text below, followed by one blank line, directly before that line, and change nothing else. Otherwise stop and report.

   ```text
   ## ADR-0031 — Publication is candidate-first: a Change Request publishes a candidate, and `main` moves only by the owner's promotion of that exact SHA

   - Date: 2026-10-15 · Status: Accepted (owner-ratified 2026-10-15). Supersedes the publication half of ADR-0009 ("Completing a CR pushes to the configured upstream"). ADR-0009's linear history stays in force.
   - **Context.** ADR-0009 published a Change Request by pushing on Complete. The repository then built another route, one contract at a time, without recording it as a decision: `SPEC-168` made one acceptance workflow, `orvion-acceptance`, run on the `orvion-preflight` branch; `SPEC-184` added `scripts/publish_candidate.ps1`, which proves the committed range with `-Gate` and pushes the candidate there and nowhere else; ruleset 22950574 requires that check on `main`; `SPEC-281` added `-Gate -Trusted` and `scripts/promote_main.ps1`. The lifecycle text still said `git push`, so an agent that followed it reached a push the ruleset is configured to refuse.
   - **Decision:**
     1. A completed Change Request is published as a candidate with `scripts/publish_candidate.ps1`, to `orvion-preflight` only. No agent pushes `main`.
     2. `main` moves only by a fast-forward to one candidate SHA that `orvion-acceptance` accepted, promoted by the owner with `scripts/promote_main.ps1` from a clean checkout of `main`.
     3. A candidate awaiting promotion is a valid intermediate state. Synchronization and `-Certify` follow promotion.
     4. The procedure is stated once, in `CR_LIFECYCLE.md` §9 (`Complete`). Other files point to it.
   - **Why.** Admission is judged on the exact SHA that becomes `main`, before it does. ADR-0009's linear history is kept, because promotion is a fast-forward.
   - **Alternatives rejected:**
     - Keeping ADR-0009's push on Complete: the ruleset is configured to refuse it, and it would move `main` before acceptance.
     - Pull requests: publication has never used them, and a merge commit is a SHA that acceptance did not judge.
     - A trusted check run from `main` by `workflow_run`: another workflow can impersonate it without an owner-held GitHub App (`SPEC-281` Notes).
   - **Consequences:**
     - The completing agent's `HEAD` is ahead of `@{u}` until promotion. That is not a blocker.
     - Promotion is the owner's action, and so is the GitHub configuration it relies on.
   - **Constraints on future work:**
     - Never push `main` from an agent, and never add a second publication route.
     - Never promote a SHA that `orvion-acceptance` did not accept, or one that does not descend from `main`.
   - **Evidence basis:**
     - PROVEN in the repository: `scripts/publish_candidate.ps1` is exercised by `scripts/test_agent_continuity.ps1`, and `scripts/promote_main.ps1` by `SPEC-281`'s tests 281-R*.
     - INFERENCE, from configuration read on 2026-10-15: ruleset 22950574 is active on the default branch with `non_fast_forward`, `deletion`, the required status check `orvion-acceptance` and an empty bypass list. That GitHub refuses a direct push of a commit lacking the check is configuration and platform documentation, not behaviour ORVION has observed, and it is deliberately not tested against the live `main`. Whether only the owner can move `main` is CTRL-19 (`MASTER_GAP_REGISTER.md`).
   - **Class:** governance / publication. **Basis:** owner-ratified (directive of 2026-10-15); system-derived (the route `SPEC-168`, `SPEC-184` and `SPEC-281` built).
   - **Related:** ADR-0009 · CTRL-19 · `CR_LIFECYCLE.md` §9 · `scripts/publish_candidate.ps1`, `scripts/promote_main.ps1`.
   - **Revisit trigger:** any of
     - CTRL-19 closed or changed;
     - a second publication route proposed, or pull requests adopted;
     - a change in how GitHub applies a ruleset's required status checks to a push.
   ```

8. **Check** whether `reports/master/MASTER_ARCHITECTURE_DECISIONS.md` contains `publication superseded by ADR-0031`. If so, record Already Applied. Otherwise, if it contains `| 0009 | Direct-to-main, publish on Complete | Reaffirmed (governs additive-migration rule) |` exactly once, replace that row with the row below, and change nothing else. Otherwise stop and report.

   ```text
   | 0009 | Direct-to-main, publish on Complete | Linear history reaffirmed (governs additive-migration rule); publication superseded by ADR-0031 (candidate-first, owner promotion) |
   ```

9. **Check** whether `reports/master/MASTER_ARCHITECTURE_DECISIONS.md` contains `Last updated: 2026-10-15 (`. If so, record Already Applied. Otherwise, if exactly one line begins `Last updated: 2026-09-28 (`, replace `Last updated:` at the start of that line with `Previously:`, insert the line below, followed by one blank line, directly before it, and change nothing else. Otherwise stop and report.

   ```text
   Last updated: 2026-10-15 (**ADR-0009's publication half is superseded by ADR-0031 (SPEC-282).** ADR-0009 published a Change Request by pushing on Complete; publication has been candidate-first since SPEC-184, and ADR-0031 records it. Linear history and the additive-migration rule keep ADR-0009.)
   ```

10. **Check** whether `changes/TEMPLATE.md` contains a line consisting only of `---`. If not, record Already Applied. Otherwise, if exactly 17 such lines exist and each is followed by one blank line, delete each of those lines together with the blank line after it, and change nothing else. Otherwise stop and report.

11. **Check** whether the projections are current: run `pwsh -NoProfile -File scripts/generate-ai-map.ps1`, which rewrites `ai-map.json` and `repository-index.md` from the canonical documents and changes no other file. If neither file's content changed, record Already Applied; otherwise record Applied.

12. **Check** whether the Runtime Checkpoint reads `Resume Step: DONE`. If so, record Already Applied. Otherwise:
    - confirm that `git diff --name-only` against the Approve commit lists only paths in this contract's Write Scope, and stop and report any other path;
    - synchronize the Execution Log, set the Runtime Checkpoint to `DONE`, and commit;
    - then run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` normally.

## Acceptance Criteria

- [x] `CR_LIFECYCLE.md` is its `349825e` text with only the Step 1 and Step 2 replacements. `check: blob CR_LIFECYCLE.md b2f7cbe8669f8af48948bcaaa03a89700949a7c2`
- [x] `AGENTS.md` is its `349825e` text with only the Step 3 and Step 4 replacements. `check: blob AGENTS.md 1b50005ad890a3446bfbfd0d1f22d7d5355a047b`
- [x] The manifest's `Next capability` line no longer carries a copy of the publication procedure, and its `GOVERNANCE.md` §6 pin is the Step 5 row. `check: lacks _ORVION_CANONICAL/manifest.md#Next capability "Standing facts:"` `check: blob GOVERNANCE.md c2badef578c2c750d12d8874fbc39af4ff10a4b4`
- [x] The manifest's `Current Module` and `Batch 6 surface coverage` lines are unchanged. `check: same _ORVION_CANONICAL/manifest.md#Current Module @349825e` `check: same _ORVION_CANONICAL/manifest.md#Batch 6 surface coverage @349825e`
- [x] The ADR log is its `349825e` text with only ADR-0009's Status qualifier and ADR-0031 added. `check: blob reports/architecture-decision-records.md 0bc32a7ec591cfbeeb7b26333ce66825d04c3e26`
- [x] The overlay is its `349825e` text with only the Step 8 row and the Step 9 freshness line. `check: blob reports/master/MASTER_ARCHITECTURE_DECISIONS.md 25518b1d51ab6289501e301bb30d41a2f2867eb1`
- [x] `changes/TEMPLATE.md` is its `349825e` text without its 17 separator lines. `check: blob changes/TEMPLATE.md af91d9bfa47d495bcc100554b821c5388ad8f5cb`
- [x] The publication scripts and the evaluator are unchanged. `check: blob scripts/publish_candidate.ps1 f55e7a165744fd0207b5da5733ae5e047f85f2a1` `check: blob scripts/promote_main.ps1 bf64aa893faf9d6be7477254bebf80dca04b4d79` `check: blob scripts/check_agent_continuity.ps1 d9d485b9a3bfa099af092648228e8bb005320471`

## Execution Log

[Appended by the executing agent after each run against this Change Request, before
IMPLEMENT is considered complete, per synchronization as defined in `CR_LIFECYCLE.md` §8
— this file is always implicitly in scope for this section.
Append-only — never edit or delete a prior entry, including a Blocked or Failed one.
Leave this section's bracketed instructions in place in an unused template; remove them
only in a CR that has at least one real entry.]

### 2026-10-15 — Claude

Outcome: Implemented. The Runtime Checkpoint is DONE; `-Finish` follows.

Step results:
- **Step 1: Applied.** The old `Complete` text occurred once in `CR_LIFECYCLE.md` and was replaced by the Step 1 text.
- **Step 2: Applied.** `run from the repository root after pushing, it reads` occurred once and was replaced. `CR_LIFECYCLE.md` is blob `b2f7cbe8669f8af48948bcaaa03a89700949a7c2`.
- **Step 3: Applied.** `synchronize, commit, push, clean tree` occurred once and was replaced.
- **Step 4: Applied.** `committed and normally pushed; relevant CI verified.` occurred once and was replaced. `AGENTS.md` is blob `1b50005ad890a3446bfbfd0d1f22d7d5355a047b`.
- **Step 5: Applied.** The "Standing facts" sentence and its leading space occurred once in the manifest and were deleted; the old pin row occurred once in `GOVERNANCE.md` and was replaced by the new one in the same edit. `GOVERNANCE.md` is blob `c2badef578c2c750d12d8874fbc39af4ff10a4b4`.
- **Step 6: Applied.** ADR-0009's Status line occurred once and was replaced.
- **Step 7: Applied.** No `## ADR-0031 ` heading existed; ADR-0031 was inserted directly before `## Programme lesson numbering (resolved 2026-08-31)`. The ADR log is blob `0bc32a7ec591cfbeeb7b26333ce66825d04c3e26`.
- **Step 8: Applied.** Row 0009 occurred once and was replaced.
- **Step 9: Applied.** One line began `Last updated: 2026-09-28 (`; it became `Previously:` and the Step 9 line was inserted before it. The overlay is blob `25518b1d51ab6289501e301bb30d41a2f2867eb1`.
- **Step 10: Applied.** `changes/TEMPLATE.md` had exactly 17 `---` lines, each followed by a blank line; all were deleted. Blob `af91d9bfa47d495bcc100554b821c5388ad8f5cb`.
- **Step 11: Applied.** `scripts/generate-ai-map.ps1` rewrote `ai-map.json`; `repository-index.md` regenerated byte-identical.
- **Step 12: Applied.** `git diff --name-only 77e7bb8` (the Approve commit) listed only Write Scope paths. The Runtime Checkpoint is DONE.

Steps 1–10 were applied from this contract's committed code blocks and quoted anchors, not retyped.

**Approval prerequisites, re-verified before the first commit.** The Draft's bytes were recomputed: blob `2215c04ca70f103cb6dd9c0cf2a308cc9385e1bb`, SHA-256 `6d8a1601495aae0207d3f714b0b71c87698105225bdea82d0a9d043be44b89e7`, 25829 bytes, 0 CR, equal to the approved identity. HEAD, `origin/main` and `origin/orvion-preflight` were `349825e` after a fetch, the tree was clean, and no stash or other worktree existed. `SPEC-282` appeared in no history or tracked text. A stale, empty `.git/index.lock` from 01:40, with no git process running, was removed before the Draft commit. No Primary or Secondary contact was made.

Commits: Draft `f554efd`, Approve `77e7bb8`, Begin `e539916`, and this Implement commit.
## Verification Notes

[Appended by the reviewing agent after independently re-checking the Execution Log
against the live repository state. Append-only — never edit or delete a prior entry.]

### 2026-10-15 — Claude (independent review)

Verdict: Confirmed Complete

Findings: re-checked against the live repository at `f468b68`, not against the Execution Log.
- **R1.** `git diff --name-only 349825e f468b68` lists only Write Scope paths: `AGENTS.md`, `CR_LIFECYCLE.md`, `GOVERNANCE.md`, `_ORVION_CANONICAL/manifest.md`, `ai-map.json`, this contract, `changes/TEMPLATE.md`, `reports/architecture-decision-records.md`, `reports/master/MASTER_ARCHITECTURE_DECISIONS.md`. `repository-index.md` regenerated byte-identical.
- **R2.** The word diff from `349825e` holds only each Step's change. `CR_LIFECYCLE.md`: the `Complete` publication text and `after pushing`. `AGENTS.md`: `push,` and `normally pushed;`. `GOVERNANCE.md`: the `Next capability` pin `c03a5e39…` → `90b037bb…`. The overlay: row 0009 and the new `Last updated:` line, with the old one kept as `Previously:`. The template: 17 lines `---` removed and nothing else. The ADR log: only ADR-0009's Status line replaced, and 31 lines added for ADR-0031. The manifest: the "Standing facts" sentence removed and the Active Change Request pointer.
- **R3.** At `HEAD` all three `GOVERNANCE.md` §6 pins reproduce their lines (`Current Module` `63c303fb…`, `Batch 6 surface coverage` `166b2f42…`, `Next capability` `90b037bb…`), computed with the evaluator's own `Get-TextSha256`.
- **R4.** Nothing changed since `349825e` in `scripts/`, `.github/`, `.githooks/`, `supabase/`, `ENGINEERING_METHOD.md`, `CODING_STANDARDS.md`, the Execution Plan, Gap Register or Repository Health Masters, or `SPEC-281`.
- **R5.** Since the Draft commit `f554efd`, this contract changed only in Status, the Runtime Checkpoint and the Execution Log, and the pre-commit Gate accepted each commit.
- **R6.** All 12 criterion checks hold in the working tree and at `HEAD`, and the Gate verifies them again at this Complete transition.
- **R7.** `-Finish` at `f468b68`: CONTROL and REPOSITORY profiles, the five control suites, repository consistency and `git diff --check` PASS, `LOCAL_CERTIFY: READY` in 37.41 min.
- **R8.** No Primary or Secondary contact, no push to `main`, and no GitHub setting, ruleset or credential change.

Carried forward, not fixed here: a keyless `check: same <path> @<commit>` never holds in the working tree because `git show` text lacks the final newline, while it holds at a commit. The owner assigned it to the multi-pass Draft assurance contract's local/CI parity proof (2026-10-15). CTRL-19 and DRAFT-REMOTE-1 stay open.

Review Gate: every step matched its text and was Applied. Nothing was written outside Write Scope, and no section was restructured. Every Acceptance Criterion is true. No step needed a guess. `Supersedes / Depends On` is None. The tree is clean.

Complete records ADR-0031, the decision the owner ratified at Gate 1 on 2026-10-15, which also authorized this completion. It introduces no other architectural decision.

Recommendation to human: Set Status to Complete

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

- **Owner direction (2026-10-15).** The owner required this change (CR A of the assurance finalization programme), ruled out a negative push experiment against the live `main`, and asked that unrelated lessons not be bundled here.
- **Considered and not adopted.**
  - *A sentence in the template telling authors to replace bracketed instructions.* Not earned: no contract in `changes/` has kept one, and the parser refuses one with a code that names the line.
  - *Making Boot show a Draft's parse refusal.* Today Boot and a PLAN-mode Gate report any unparseable Draft only as `NO_GOVERNING_CR:<path>`; the code appears at Approval. That changes the evaluator, so it belongs with the multi-pass Draft assurance contract, which makes Boot report a pending Draft.
  - *Testing GitHub's refusal of a direct push to `main`.* Not authorized; ADR-0031 records it as inference.
  - *A keyless `check: same <path> @<commit>`.* Measured on this contract's rehearsal: it compares `git show` text, which drops the final newline, with the working-tree text, which keeps it, so it fails in the hook and `-Finish` and holds in the range Gate. No contract has used it. Criterion 8 uses `blob` instead; the evaluator fix belongs to a contract that changes the evaluator.
- **Rehearsal.** The prototype was applied to a clean clone of `349825e` with a local bare remote, and this contract's Draft, Approve, Begin and Implement commits were judged by the pre-commit hook and by the range Gate over the future publication range. `-Finish` runs at implementation.
- **Not this contract's work:** the Actions supply-chain contract, the multi-pass Draft assurance contract, CTRL-19, and Batch 6 Slice 43.
